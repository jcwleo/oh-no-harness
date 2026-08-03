#!/usr/bin/env node

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmod,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  realpath,
  rename,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  formatPreferenceWriteResult,
  writePreferenceAssignments,
} from "../plugins/oh-no-harness/opencode/preference-writer.js";
import {
  inspectDirectoryPath,
  PREFERENCES_FILENAME,
  readPreferenceState,
  ROLES,
  sameDirectoryIdentity,
} from "../plugins/oh-no-harness/opencode/preferences.js";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const configurator = path.join(
  repoRoot,
  "plugins/oh-no-harness/opencode/configure-opencode-subagents",
);
const assignments = Object.fromEntries(
  ROLES.map((role) => [role, `test-provider/${role}`]),
);
const alternateAssignments = Object.fromEntries(
  ROLES.map((role) => [role, `alternate/${role}`]),
);
const prior = Buffer.from("prior preference bytes\n");
const lockName = ".opencode-subagent-models.lock";
const temporaryRoot = await mkdtemp(
  path.join(await realpath(os.tmpdir()), "oh-no-opencode-prefs-"),
);

async function publish(directory, value = assignments, options = {}) {
  return writePreferenceAssignments(value, {
    environment: { OH_NO_CONFIG_DIR: directory },
    ...options,
  });
}

async function makeDirectory(name, mode) {
  const directory = path.join(temporaryRoot, name);
  await mkdir(directory, { mode });
  await chmod(directory, mode);
  const stats = await stat(directory);
  if (typeof process.getuid === "function") assert.equal(stats.uid, process.getuid());
  return directory;
}

async function assertPriorBytes(directory, result, status) {
  assert.equal(result.status, status);
  assert.equal(result.published, false);
  assert.deepEqual(await readFile(path.join(directory, PREFERENCES_FILENAME)), prior);
}

function ownerRecord(pid) {
  return {
    schema_version: 1,
    pid,
    host: os.hostname(),
    token: "0123456789abcdef0123456789abcdef",
    uid: process.getuid(),
  };
}

async function makeLock(directory, owner) {
  const lock = path.join(directory, lockName);
  await mkdir(lock, { mode: 0o700 });
  if (owner !== undefined) {
    await writeFile(
      path.join(lock, "owner.json"),
      typeof owner === "string" ? owner : `${JSON.stringify(owner)}\n`,
      { mode: 0o600 },
    );
  }
  return lock;
}

async function assertNoLockArtifacts(directory) {
  const artifacts = (await readdir(directory)).filter((entry) => entry.startsWith(lockName));
  assert.deepEqual(artifacts, []);
}

try {
  assert.notEqual(process.platform, "win32", "POSIX writer tests require a POSIX host");

  for (const mode of [0o700, 0o755]) {
    const directory = await makeDirectory(`valid-${mode.toString(8)}`, mode);
    const inspected = await inspectDirectoryPath(directory);
    assert.equal(inspected.valid, true);
    assert.equal(inspected.exists, true);
    const result = await publish(directory);
    assert.deepEqual(result, { status: "configured", published: true });
    assert.match(formatPreferenceWriteResult(result), /STATUS: configured/u);
    assert.match(formatPreferenceWriteResult(result), /RESTART REQUIRED/u);
    assert.equal((await readPreferenceState({ OH_NO_CONFIG_DIR: directory })).status, "configured");
  }

  for (const mode of [0o777, 0o770]) {
    const directory = await makeDirectory(`insecure-${mode.toString(8)}`, 0o700);
    const destination = path.join(directory, PREFERENCES_FILENAME);
    await writeFile(destination, prior);
    await chmod(directory, mode);
    assert.equal((await inspectDirectoryPath(directory)).valid, false);
    await assertPriorBytes(directory, await publish(directory, alternateAssignments), "ambiguous-config");
  }

  const identityA = await makeDirectory("identity-a", 0o700);
  const identityB = await makeDirectory("identity-b", 0o700);
  const firstIdentity = await stat(identityA);
  assert.equal(sameDirectoryIdentity(firstIdentity, await stat(identityA)), true);
  assert.equal(sameDirectoryIdentity(firstIdentity, await stat(identityB)), false);
  const movedIdentity = `${identityA}-moved`;
  await rename(identityA, movedIdentity);
  await mkdir(identityA, { mode: 0o700 });
  assert.equal(sameDirectoryIdentity(firstIdentity, await stat(identityA)), false);

  const symlinkTarget = await makeDirectory("leaf-symlink-target", 0o700);
  await writeFile(path.join(symlinkTarget, PREFERENCES_FILENAME), prior);
  const leafSymlink = path.join(temporaryRoot, "leaf-symlink");
  await symlink(symlinkTarget, leafSymlink);
  assert.equal((await inspectDirectoryPath(leafSymlink)).valid, false);
  await assertPriorBytes(symlinkTarget, await publish(leafSymlink), "ambiguous-config");

  const ancestorTarget = await makeDirectory("ancestor-target", 0o700);
  const ancestorConfig = path.join(ancestorTarget, "config");
  await mkdir(ancestorConfig, { mode: 0o700 });
  await writeFile(path.join(ancestorConfig, PREFERENCES_FILENAME), prior);
  const ancestorSymlink = path.join(temporaryRoot, "ancestor-symlink");
  await symlink(ancestorTarget, ancestorSymlink);
  const throughAncestor = path.join(ancestorSymlink, "config");
  assert.equal((await inspectDirectoryPath(throughAncestor)).valid, false);
  await assertPriorBytes(ancestorConfig, await publish(throughAncestor), "ambiguous-config");

  const symlinkDestinationDirectory = await makeDirectory("destination-symlink", 0o700);
  const destinationTarget = path.join(temporaryRoot, "destination-target");
  await writeFile(destinationTarget, prior);
  await symlink(destinationTarget, path.join(symlinkDestinationDirectory, PREFERENCES_FILENAME));
  const symlinkResult = await publish(symlinkDestinationDirectory);
  assert.deepEqual(symlinkResult, { status: "unsafe-destination", published: false });
  assert.deepEqual(await readFile(destinationTarget), prior);
  assert.equal((await lstat(path.join(symlinkDestinationDirectory, PREFERENCES_FILENAME))).isSymbolicLink(), true);

  const malformedDestinationDirectory = await makeDirectory("malformed-destination", 0o700);
  const malformedDestination = path.join(malformedDestinationDirectory, PREFERENCES_FILENAME);
  await mkdir(malformedDestination, { mode: 0o700 });
  await writeFile(path.join(malformedDestination, "sentinel"), prior);
  assert.deepEqual(await publish(malformedDestinationDirectory), {
    status: "unsafe-destination",
    published: false,
  });
  assert.deepEqual(await readFile(path.join(malformedDestination, "sentinel")), prior);

  const malformedArgumentsDirectory = await makeDirectory("malformed-arguments", 0o700);
  await writeFile(path.join(malformedArgumentsDirectory, PREFERENCES_FILENAME), prior);
  for (const invalid of [
    { explore: "missing-roles/model" },
    { ...assignments, extra: "provider/model" },
    { ...assignments, "code-reviewer": "missing-provider-slash" },
  ]) {
    await assertPriorBytes(
      malformedArgumentsDirectory,
      await publish(malformedArgumentsDirectory, invalid),
      "invalid-assignments",
    );
  }

  const successDirectory = await makeDirectory("successful-atomic-publish", 0o700);
  const success = await publish(successDirectory, alternateAssignments);
  assert.deepEqual(success, { status: "configured", published: true });
  const state = await readPreferenceState({ OH_NO_CONFIG_DIR: successDirectory });
  assert.equal(state.status, "configured");
  for (const role of ROLES) assert.equal(state.assignments.get(role), `alternate/${role}`);
  assert.deepEqual(await readdir(successDirectory), [PREFERENCES_FILENAME]);

  const liveLockDirectory = await makeDirectory("live-lock", 0o700);
  await writeFile(path.join(liveLockDirectory, PREFERENCES_FILENAME), prior);
  await makeLock(liveLockDirectory, ownerRecord(process.pid));
  await assertPriorBytes(liveLockDirectory, await publish(liveLockDirectory), "locked");
  assert.deepEqual(await readdir(path.join(liveLockDirectory, lockName)), ["owner.json"]);

  const deadPid = 2_147_483_647;
  assert.throws(() => process.kill(deadPid, 0), { code: "ESRCH" });
  const staleLockDirectory = await makeDirectory("stale-lock", 0o700);
  await writeFile(path.join(staleLockDirectory, PREFERENCES_FILENAME), prior);
  await makeLock(staleLockDirectory, ownerRecord(deadPid));
  assert.deepEqual(await publish(staleLockDirectory, alternateAssignments), {
    status: "configured",
    published: true,
  });
  assert.equal(
    (await readPreferenceState({ OH_NO_CONFIG_DIR: staleLockDirectory })).assignments.get("explore"),
    "alternate/explore",
  );
  await assertNoLockArtifacts(staleLockDirectory);

  for (const [name, owner] of [
    ["missing-owner-lock", undefined],
    ["malformed-owner-lock", "not-json\n"],
    ["foreign-owner-lock", { ...ownerRecord(deadPid), host: "foreign-host.invalid" }],
  ]) {
    const directory = await makeDirectory(name, 0o700);
    await writeFile(path.join(directory, PREFERENCES_FILENAME), prior);
    await makeLock(directory, owner);
    await assertPriorBytes(directory, await publish(directory), "locked");
    assert.deepEqual(await readdir(path.join(directory, lockName)), owner === undefined ? [] : ["owner.json"]);
  }

  const concurrentDirectory = await makeDirectory("concurrent-stale-reclaim", 0o700);
  await makeLock(concurrentDirectory, ownerRecord(deadPid));
  const concurrentResults = await Promise.all([
    publish(concurrentDirectory, assignments),
    publish(concurrentDirectory, alternateAssignments),
  ]);
  assert.equal(concurrentResults.filter((result) => result.status === "configured").length, 1);
  assert.equal(concurrentResults.filter((result) => result.status === "locked").length, 1);
  const concurrentState = await readPreferenceState({ OH_NO_CONFIG_DIR: concurrentDirectory });
  assert.equal(concurrentState.status, "configured");
  const configuredPrefix = concurrentState.assignments.get("explore").split("/", 1)[0];
  for (const role of ROLES) {
    assert.equal(concurrentState.assignments.get(role), `${configuredPrefix}/${role}`);
  }
  await assertNoLockArtifacts(concurrentDirectory);

  const indeterminateDirectory = await makeDirectory("indeterminate", 0o700);
  await writeFile(path.join(indeterminateDirectory, PREFERENCES_FILENAME), prior);
  let syncCount = 0;
  const indeterminate = await publish(indeterminateDirectory, alternateAssignments, {
    syncDirectory: async (handle) => {
      syncCount += 1;
      if (syncCount === 3) throw new Error("injected post-rename fsync failure");
      await handle.sync();
    },
  });
  assert.deepEqual(indeterminate, {
    status: "indeterminate-durability",
    published: true,
  });
  const indeterminateText = formatPreferenceWriteResult(indeterminate);
  assert.match(indeterminateText, /STATUS: indeterminate-durability/u);
  assert.match(indeterminateText, /preferences were published/u);
  assert.doesNotMatch(indeterminateText, /preferences were not changed/iu);
  assert.equal(
    (await readPreferenceState({ OH_NO_CONFIG_DIR: indeterminateDirectory })).status,
    "configured",
  );

  const windowsDirectory = path.join(temporaryRoot, "windows-unsupported");
  assert.deepEqual(
    await publish(windowsDirectory, assignments, { platform: "win32" }),
    { status: "unsupported-platform", published: false },
  );
  await assert.rejects(lstat(windowsDirectory), { code: "ENOENT" });

  const legacyDirectory = await makeDirectory("legacy-cli-nonwriting", 0o700);
  await writeFile(path.join(legacyDirectory, PREFERENCES_FILENAME), prior);
  const legacyApply = spawnSync(
    process.execPath,
    [configurator, "apply", ...ROLES.map((role) => `${role}=legacy/${role}`)],
    {
      encoding: "utf8",
      env: { ...process.env, OH_NO_CONFIG_DIR: legacyDirectory },
    },
  );
  assert.equal(legacyApply.status, 2, `${legacyApply.stdout}\n${legacyApply.stderr}`);
  assert.match(legacyApply.stderr, /Usage: configure-opencode-subagents check/u);
  assert.deepEqual(await readFile(path.join(legacyDirectory, PREFERENCES_FILENAME)), prior);

  const check = spawnSync(process.execPath, [configurator, "check"], {
    encoding: "utf8",
    env: { ...process.env, OH_NO_CONFIG_DIR: successDirectory },
  });
  assert.equal(check.status, 0, `${check.stdout}\n${check.stderr}`);
  assert.equal(check.stdout.trim(), "STATUS: configured");

  console.log("PASS: focused OpenCode preference reader, writer, and read-only CLI tests");
} finally {
  await rm(temporaryRoot, { recursive: true, force: true });
}
