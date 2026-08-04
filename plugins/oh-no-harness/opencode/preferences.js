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
export const MODEL_SCHEMA_PATTERN = "^[\\s\\S]+\\/[\\s\\S]+$";
export const VARIANT_SCHEMA_PATTERN = "^[\\s\\S]+$";
export const DEFAULT_VARIANT = "default";

const MODEL_PATTERN = new RegExp(MODEL_SCHEMA_PATTERN, "u");
const VARIANT_PATTERN = new RegExp(VARIANT_SCHEMA_PATTERN, "u");
const LEGACY_MODEL_PATTERN = /^[^\s,=/]+\/[^\s,=]+$/u;

function normalizeAssignment(value) {
  if (typeof value === "string") {
    return MODEL_PATTERN.test(value)
      ? { model: value, variant: DEFAULT_VARIANT }
      : null;
  }
  if (!value || Array.isArray(value) || typeof value !== "object") return null;
  if (Object.keys(value).sort().join("\0") !== "model\0variant") return null;
  if (typeof value.model !== "string" || !MODEL_PATTERN.test(value.model)) return null;
  if (typeof value.variant !== "string" || !VARIANT_PATTERN.test(value.variant)) return null;
  return { model: value.model, variant: value.variant };
}

export function normalizeModelAssignments(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;

  const entries = value instanceof Map ? [...value] : Object.entries(value);
  if (entries.length !== ROLES.length) return null;
  const source = new Map(entries);
  if (source.size !== ROLES.length || ROLES.some((role) => !source.has(role))) return null;

  const assignments = new Map();
  for (const role of ROLES) {
    const assignment = normalizeAssignment(source.get(role));
    if (!assignment) return null;
    assignments.set(role, assignment);
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

    const [model, variant = DEFAULT_VARIANT, ...extra] = argument.slice(prefix.length).split(",");
    if (extra.length > 0) return null;
    const assignment = normalizeAssignment({ model, variant });
    if (!assignment) return null;
    assignments.set(ROLES[index], assignment);
  }
  return normalizeModelAssignments(assignments);
}

export function parsePreferences(contents) {
  if (typeof contents !== "string" || contents.includes("\r")) return null;

  const lines = contents.endsWith("\n")
    ? contents.slice(0, -1).split("\n")
    : contents.split("\n");
  const schemaVersion = lines[0];
  if (
    lines.length !== ROLES.length + 1 ||
    (schemaVersion !== "schema_version=1" && schemaVersion !== "schema_version=2")
  ) {
    return null;
  }

  const assignments = new Map();
  for (let index = 0; index < ROLES.length; index += 1) {
    const role = ROLES[index];
    const prefix = `assignment=${role},`;
    const line = lines[index + 1];

    let assignment;
    if (schemaVersion === "schema_version=1") {
      if (!line.startsWith(prefix)) return null;
      const model = line.slice(prefix.length);
      assignment = LEGACY_MODEL_PATTERN.test(model)
        ? { model, variant: DEFAULT_VARIANT }
        : null;
    } else {
      if (!line.startsWith("assignment=")) return null;
      try {
        const value = JSON.parse(line.slice("assignment=".length));
        if (
          !value ||
          Array.isArray(value) ||
          typeof value !== "object" ||
          Object.keys(value).sort().join("\0") !== "model\0role\0variant" ||
          value.role !== role
        ) {
          return null;
        }
        assignment = normalizeAssignment({ model: value.model, variant: value.variant });
      } catch {
        return null;
      }
    }
    if (!assignment) return null;
    assignments.set(role, assignment);
  }
  return assignments;
}

export function renderPreferences(assignments) {
  const lines = ["schema_version=2"];
  for (const role of ROLES) {
    const assignment = assignments.get(role);
    lines.push(`assignment=${JSON.stringify({ role, ...assignment })}`);
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
