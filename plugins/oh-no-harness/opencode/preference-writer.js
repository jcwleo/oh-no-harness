import { constants } from "node:fs";
import { randomBytes } from "node:crypto";
import { lstat, mkdir, open, readdir, rename, rmdir, unlink } from "node:fs/promises";
import { hostname } from "node:os";
import path from "node:path";

import {
  inspectDirectoryPath,
  isSecureConfigDirectory,
  normalizeModelAssignments,
  PREFERENCES_FILENAME,
  renderPreferences,
  resolveConfigDirectory,
  sameDirectoryIdentity,
} from "./preferences.js";

const LOCK_NAME = ".opencode-subagent-models.lock";
const LOCK_OWNER_NAME = "owner.json";
const LOCK_RECLAIM_NAME = ".reclaim";
const LOCK_SCHEMA_VERSION = 1;

function supportsConfigurationWrites(platform) {
  return (
    platform !== "win32" &&
    Number.isInteger(constants.O_DIRECTORY) &&
    Number.isInteger(constants.O_NOFOLLOW)
  );
}

async function ensureConfigDirectory(directory) {
  const initial = await inspectDirectoryPath(directory);
  if (!initial.valid) return false;
  if (initial.exists) return true;

  const root = path.parse(directory).root;
  const parts = directory.slice(root.length).split(path.sep).filter(Boolean);
  let current = root;
  for (const part of parts) {
    current = path.join(current, part);
    try {
      await mkdir(current, { mode: 0o700 });
    } catch (error) {
      if (error?.code !== "EEXIST") return false;
    }

    try {
      const stats = await lstat(current);
      if (stats.isSymbolicLink() || !stats.isDirectory()) return false;
    } catch {
      return false;
    }
  }
  const final = await inspectDirectoryPath(directory);
  return final.valid && final.exists;
}

async function destinationIsSafe(file) {
  let handle;
  try {
    const stats = await lstat(file);
    if (stats.isSymbolicLink() || !stats.isFile()) return false;

    handle = await open(file, constants.O_RDONLY | constants.O_NOFOLLOW);
    return (await handle.stat()).isFile();
  } catch (error) {
    return error?.code === "ENOENT";
  } finally {
    await handle?.close();
  }
}

async function openConfigDirectory(directory, syncDirectory) {
  let handle;
  try {
    handle = await open(
      directory,
      constants.O_RDONLY | constants.O_DIRECTORY | constants.O_NOFOLLOW,
    );
    const stats = await handle.stat();
    const pathStats = await lstat(directory);
    if (
      pathStats.isSymbolicLink() ||
      !isSecureConfigDirectory(stats) ||
      !isSecureConfigDirectory(pathStats) ||
      !sameDirectoryIdentity(stats, pathStats)
    ) {
      await handle.close();
      return null;
    }
    // Establish that this filesystem supports directory fsync before publication.
    await syncDirectory(handle);
    return { handle, stats };
  } catch {
    await handle?.close().catch(() => {});
    return null;
  }
}

async function directoryPathStillMatches(directory, openedStats) {
  const pathState = await inspectDirectoryPath(directory);
  if (!pathState.valid || !pathState.exists) return false;

  try {
    const stats = await lstat(directory);
    return (
      !stats.isSymbolicLink() &&
      isSecureConfigDirectory(stats) &&
      sameDirectoryIdentity(openedStats, stats)
    );
  } catch {
    return false;
  }
}

function lockToken() {
  return randomBytes(16).toString("hex");
}

function lockOwner() {
  const owner = {
    schema_version: LOCK_SCHEMA_VERSION,
    pid: process.pid,
    host: hostname(),
    token: lockToken(),
  };
  if (typeof process.getuid === "function") owner.uid = process.getuid();
  return owner;
}

async function writeLockOwner(lock, owner) {
  const ownerPath = path.join(lock, LOCK_OWNER_NAME);
  const handle = await open(
    ownerPath,
    constants.O_WRONLY |
      constants.O_CREAT |
      constants.O_EXCL |
      constants.O_NOFOLLOW,
    0o600,
  );
  try {
    await handle.writeFile(`${JSON.stringify(owner)}\n`, "utf8");
    await handle.sync();
  } finally {
    await handle.close();
  }
}

async function readLockOwner(lock) {
  if (typeof process.getuid !== "function") return null;
  const currentUid = process.getuid();
  const ownerPath = path.join(lock, LOCK_OWNER_NAME);
  let handle;
  try {
    const lockStats = await lstat(lock);
    if (lockStats.isSymbolicLink() || !isSecureConfigDirectory(lockStats)) return null;

    const pathStats = await lstat(ownerPath);
    if (
      pathStats.isSymbolicLink() ||
      !pathStats.isFile() ||
      pathStats.uid !== currentUid ||
      (pathStats.mode & 0o022) !== 0 ||
      pathStats.size > 4096
    ) {
      return null;
    }
    handle = await open(ownerPath, constants.O_RDONLY | constants.O_NOFOLLOW);
    const stats = await handle.stat();
    if (!stats.isFile() || !sameDirectoryIdentity(stats, pathStats)) return null;
    const value = JSON.parse(await handle.readFile("utf8"));
    const expectedKeys = ["host", "pid", "schema_version", "token", "uid"];
    if (
      !value ||
      Array.isArray(value) ||
      typeof value !== "object" ||
      Object.keys(value).sort().join("\0") !== expectedKeys.join("\0") ||
      value.schema_version !== LOCK_SCHEMA_VERSION ||
      value.uid !== currentUid ||
      !Number.isSafeInteger(value.pid) ||
      value.pid <= 0 ||
      value.host !== hostname() ||
      !/^[0-9a-f]{32}$/u.test(value.token)
    ) {
      return null;
    }
    return { owner: value, lockStats };
  } catch {
    return null;
  } finally {
    await handle?.close().catch(() => {});
  }
}

function processIsDemonstrablyDead(pid) {
  try {
    process.kill(pid, 0);
    return false;
  } catch (error) {
    return error?.code === "ESRCH";
  }
}

async function createFreshLock(lock, directoryHandle, syncDirectory) {
  await mkdir(lock, { mode: 0o700 });
  const owner = lockOwner();
  try {
    await writeLockOwner(lock, owner);
    const lockStats = await lstat(lock);
    if (!isSecureConfigDirectory(lockStats)) throw new Error("unsafe lock directory");
    await syncDirectory(directoryHandle);
    return { owner, lockStats };
  } catch (error) {
    await unlink(path.join(lock, LOCK_OWNER_NAME)).catch(() => {});
    await rmdir(lock).catch(() => {});
    throw error;
  }
}

async function removeOwnedGuard(guardPath, guardStats) {
  try {
    const stats = await lstat(guardPath);
    if (sameDirectoryIdentity(stats, guardStats)) await unlink(guardPath);
  } catch {
    // Another conservative lock outcome needs no cleanup from this contender.
  }
}

async function reclaimStaleLock(lock, directoryHandle, syncDirectory) {
  const observed = await readLockOwner(lock);
  if (!observed || !processIsDemonstrablyDead(observed.owner.pid)) return null;

  const guardPath = path.join(lock, LOCK_RECLAIM_NAME);
  let guardHandle;
  let guardStats;
  try {
    guardHandle = await open(
      guardPath,
      constants.O_WRONLY |
        constants.O_CREAT |
        constants.O_EXCL |
        constants.O_NOFOLLOW,
      0o600,
    );
    await guardHandle.writeFile(`${lockToken()}\n`, "utf8");
    await guardHandle.sync();
    guardStats = await guardHandle.stat();
  } catch {
    await guardHandle?.close().catch(() => {});
    return null;
  }
  await guardHandle.close();

  let quarantined = false;
  const quarantine = `${lock}.stale-${process.pid}-${lockToken()}`;
  try {
    const state = await readLockOwner(lock);
    if (
      !state ||
      state.owner.token !== observed.owner.token ||
      !sameDirectoryIdentity(state.lockStats, observed.lockStats) ||
      !processIsDemonstrablyDead(state.owner.pid)
    ) {
      return null;
    }
    const entries = (await readdir(lock)).sort();
    if (entries.join("\0") !== [LOCK_RECLAIM_NAME, LOCK_OWNER_NAME].sort().join("\0")) {
      return null;
    }
    const currentStats = await lstat(lock);
    if (!sameDirectoryIdentity(currentStats, state.lockStats)) return null;

    // The exclusive guard serializes reclaimers; rename atomically quarantines
    // exactly the stale directory so cleanup can never target a new live lock.
    await rename(lock, quarantine);
    quarantined = true;
    await syncDirectory(directoryHandle);
    try {
      return await createFreshLock(lock, directoryHandle, syncDirectory);
    } catch {
      return null;
    }
  } finally {
    if (quarantined) {
      await unlink(path.join(quarantine, LOCK_RECLAIM_NAME)).catch(() => {});
      await unlink(path.join(quarantine, LOCK_OWNER_NAME)).catch(() => {});
      await rmdir(quarantine).catch(() => {});
      await syncDirectory(directoryHandle).catch(() => {});
    } else if (guardStats) {
      await removeOwnedGuard(guardPath, guardStats);
    }
  }
}

async function acquirePreferenceLock(lock, directoryHandle, syncDirectory) {
  try {
    return await createFreshLock(lock, directoryHandle, syncDirectory);
  } catch (error) {
    if (error?.code !== "EEXIST") return null;
  }
  return reclaimStaleLock(lock, directoryHandle, syncDirectory);
}

async function releasePreferenceLock(lock, acquisition, directoryHandle, syncDirectory) {
  const state = await readLockOwner(lock);
  if (
    !state ||
    state.owner.token !== acquisition.owner.token ||
    !sameDirectoryIdentity(state.lockStats, acquisition.lockStats)
  ) {
    return;
  }
  const entries = await readdir(lock);
  if (entries.length !== 1 || entries[0] !== LOCK_OWNER_NAME) return;
  await unlink(path.join(lock, LOCK_OWNER_NAME));
  await rmdir(lock);
  await syncDirectory(directoryHandle);
}

export async function writePreferenceAssignments(
  value,
  {
    environment = process.env,
    platform = process.platform,
    syncDirectory = (handle) => handle.sync(),
  } = {},
) {
  const assignments = normalizeModelAssignments(value);
  if (!assignments) return { status: "invalid-assignments", published: false };
  if (!supportsConfigurationWrites(platform)) {
    return { status: "unsupported-platform", published: false };
  }

  const directory = resolveConfigDirectory(environment);
  if (!directory || !(await ensureConfigDirectory(directory))) {
    return { status: "ambiguous-config", published: false };
  }

  const openedDirectory = await openConfigDirectory(directory, syncDirectory);
  if (!openedDirectory) return { status: "ambiguous-config", published: false };

  const lock = path.join(directory, LOCK_NAME);
  const acquisition = await acquirePreferenceLock(
    lock,
    openedDirectory.handle,
    syncDirectory,
  );
  if (!acquisition) {
    await openedDirectory.handle.close();
    return { status: "locked", published: false };
  }

  const destination = path.join(directory, PREFERENCES_FILENAME);
  const temporary = path.join(
    directory,
    `.${PREFERENCES_FILENAME}.${process.pid}.${Date.now()}.tmp`,
  );
  let temporaryExists = false;
  let published = false;
  try {
    if (!(await destinationIsSafe(destination))) {
      return { status: "unsafe-destination", published };
    }

    const handle = await open(
      temporary,
      constants.O_WRONLY |
        constants.O_CREAT |
        constants.O_EXCL |
        constants.O_NOFOLLOW,
      0o600,
    );
    temporaryExists = true;
    try {
      await handle.writeFile(renderPreferences(assignments), "utf8");
      await handle.sync();
    } finally {
      await handle.close();
    }

    if (!(await destinationIsSafe(destination))) {
      return { status: "unsafe-destination", published };
    }
    // Node has no portable openat/renameat API. The final directory is therefore
    // restricted to the current UID and is not group/world writable.
    if (!(await directoryPathStillMatches(directory, openedDirectory.stats))) {
      return { status: "ambiguous-config", published };
    }
    await rename(temporary, destination);
    temporaryExists = false;
    published = true;
    await syncDirectory(openedDirectory.handle);
    return { status: "configured", published };
  } catch {
    return {
      status: published ? "indeterminate-durability" : "write-failed",
      published,
    };
  } finally {
    if (temporaryExists) await unlink(temporary).catch(() => {});
    await releasePreferenceLock(
      lock,
      acquisition,
      openedDirectory.handle,
      syncDirectory,
    ).catch(() => {});
    await openedDirectory.handle.close().catch(() => {});
  }
}

export function formatPreferenceWriteResult(result) {
  if (result.status === "configured") {
    return [
      "STATUS: configured",
      "RESTART REQUIRED: quit and restart OpenCode to load the new subagent models.",
    ].join("\n");
  }
  if (result.status === "indeterminate-durability") {
    return [
      "STATUS: indeterminate-durability",
      "WARNING: preferences were published, but directory durability could not be confirmed.",
      "RESTART REQUIRED: check status, then quit and restart OpenCode before relying on the new models.",
    ].join("\n");
  }
  return `STATUS: ${result.status}\nPreferences were not changed.`;
}
