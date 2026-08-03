import { constants } from "node:fs";
import { lstat, open } from "node:fs/promises";
import path from "node:path";

export const ROLES = Object.freeze([
  "explore",
  "analyst",
  "planner",
  "plan-reviewer",
  "executor",
  "debugger",
  "verifier",
  "code-reviewer",
  "fusion-rescue-analyst",
]);

export const PREFERENCES_FILENAME = "opencode-subagent-models.conf";
export const MODEL_SCHEMA_PATTERN = "^[^\\s,=/]+\\/[^\\s,=]+$";

const MODEL_PATTERN = new RegExp(MODEL_SCHEMA_PATTERN, "u");

export function normalizeModelAssignments(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;

  const entries = value instanceof Map ? [...value] : Object.entries(value);
  if (entries.length !== ROLES.length) return null;
  const source = new Map(entries);
  if (source.size !== ROLES.length || ROLES.some((role) => !source.has(role))) return null;

  const assignments = new Map();
  for (const role of ROLES) {
    const model = source.get(role);
    if (typeof model !== "string" || !MODEL_PATTERN.test(model)) return null;
    assignments.set(role, model);
  }
  return assignments;
}

export function parseModelAssignments(args) {
  if (args.length !== ROLES.length) return null;

  const assignments = new Map();
  for (let index = 0; index < ROLES.length; index += 1) {
    const prefix = `${ROLES[index]}=`;
    const argument = args[index];
    if (!argument.startsWith(prefix)) return null;

    const model = argument.slice(prefix.length);
    if (!MODEL_PATTERN.test(model)) return null;
    assignments.set(ROLES[index], model);
  }
  return normalizeModelAssignments(assignments);
}

export function parsePreferences(contents) {
  if (typeof contents !== "string" || contents.includes("\r")) return null;

  const lines = contents.endsWith("\n")
    ? contents.slice(0, -1).split("\n")
    : contents.split("\n");
  if (lines.length !== ROLES.length + 1 || lines[0] !== "schema_version=1") {
    return null;
  }

  const assignments = new Map();
  for (let index = 0; index < ROLES.length; index += 1) {
    const role = ROLES[index];
    const prefix = `assignment=${role},`;
    const line = lines[index + 1];
    if (!line.startsWith(prefix)) return null;

    const model = line.slice(prefix.length);
    if (!MODEL_PATTERN.test(model)) return null;
    assignments.set(role, model);
  }
  return assignments;
}

export function renderPreferences(assignments) {
  const lines = ["schema_version=1"];
  for (const role of ROLES) {
    lines.push(`assignment=${role},${assignments.get(role)}`);
  }
  return `${lines.join("\n")}\n`;
}

export function resolveConfigDirectory(environment = process.env) {
  let candidate;
  if (environment.OH_NO_CONFIG_DIR) {
    candidate = environment.OH_NO_CONFIG_DIR;
  } else if (environment.XDG_CONFIG_HOME) {
    candidate = path.join(environment.XDG_CONFIG_HOME, "oh-no-harness");
  } else if (environment.HOME) {
    candidate = path.join(environment.HOME, ".config", "oh-no-harness");
  } else {
    return null;
  }

  if (candidate.includes("\0") || !path.isAbsolute(candidate)) return null;
  return path.normalize(candidate);
}

export function isSecureConfigDirectory(stats) {
  if (!stats.isDirectory() || (stats.mode & 0o022) !== 0) return false;
  return typeof process.getuid !== "function" || stats.uid === process.getuid();
}

export function sameDirectoryIdentity(first, second) {
  return first.dev === second.dev && first.ino === second.ino;
}

export async function inspectDirectoryPath(directory) {
  const absolute = path.normalize(directory);
  const root = path.parse(absolute).root;
  const parts = absolute.slice(root.length).split(path.sep).filter(Boolean);
  let current = root;

  if (parts.length === 0) {
    try {
      const stats = await lstat(root);
      return {
        valid: !stats.isSymbolicLink() && isSecureConfigDirectory(stats),
        exists: true,
        firstMissing: 0,
      };
    } catch {
      return { valid: false, exists: false };
    }
  }

  for (let index = 0; index < parts.length; index += 1) {
    current = path.join(current, parts[index]);
    let stats;
    try {
      stats = await lstat(current);
    } catch (error) {
      if (error?.code === "ENOENT") {
        return { valid: true, exists: false, firstMissing: index };
      }
      return { valid: false, exists: false };
    }
    if (stats.isSymbolicLink() || !stats.isDirectory()) {
      return { valid: false, exists: false };
    }
    if (index === parts.length - 1 && !isSecureConfigDirectory(stats)) {
      return { valid: false, exists: true };
    }
  }

  return { valid: true, exists: true, firstMissing: parts.length };
}

async function readRegularFile(file) {
  let handle;
  try {
    const noFollow = constants.O_NOFOLLOW ?? 0;
    handle = await open(file, constants.O_RDONLY | noFollow);
    const stats = await handle.stat();
    if (!stats.isFile()) return null;
    return await handle.readFile();
  } finally {
    await handle?.close();
  }
}

export async function readPreferenceState(environment = process.env) {
  const directory = resolveConfigDirectory(environment);
  if (!directory) return { status: "ambiguous-config" };

  const directoryState = await inspectDirectoryPath(directory);
  if (!directoryState.valid) return { status: "ambiguous-config" };
  if (!directoryState.exists) return { status: "unconfigured", directory };

  const file = path.join(directory, PREFERENCES_FILENAME);
  let stats;
  try {
    stats = await lstat(file);
  } catch (error) {
    if (error?.code === "ENOENT") return { status: "unconfigured", directory };
    return { status: "invalid-preferences", directory };
  }
  if (stats.isSymbolicLink() || !stats.isFile()) {
    return { status: "invalid-preferences", directory };
  }

  try {
    const bytes = await readRegularFile(file);
    if (!bytes) return { status: "invalid-preferences", directory };
    const contents = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    const assignments = parsePreferences(contents);
    if (!assignments) return { status: "invalid-preferences", directory };
    return { status: "configured", directory, assignments };
  } catch {
    return { status: "invalid-preferences", directory };
  }
}
