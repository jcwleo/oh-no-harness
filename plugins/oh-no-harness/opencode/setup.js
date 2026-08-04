#!/usr/bin/env node

import {
  constants,
  lstat,
  mkdir,
  open,
  realpath,
  rename,
  rm,
} from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import process from "node:process";

import {
  applyEdits,
  modify,
  parse,
  printParseErrorCode,
} from "jsonc-parser";

const PACKAGE_NAME = "oh-no-harness";
const SCHEMA_URL = "https://opencode.ai/config.json";
const CONFIG_FILENAMES = ["config.json", "opencode.json", "opencode.jsonc"];
const MODEL_SETUP_NEXT_STEP =
  "NEXT: quit any running OpenCode, start OpenCode, and run /configure-subagents to choose exact subagent models and variants.";

function usage() {
  return [
    "Usage: oh-no-harness setup [--check]",
    "",
    "Register the Oh No Harness npm plugin in the effective OpenCode global config.",
  ].join("\n");
}

function configDirectory() {
  const explicit = process.env.OPENCODE_CONFIG_DIR?.trim();
  if (explicit) return path.resolve(explicit);
  const xdg = process.env.XDG_CONFIG_HOME?.trim();
  if (xdg) return path.resolve(xdg, "opencode");
  return path.join(homedir(), ".config", "opencode");
}

async function existingRegularFile(file) {
  try {
    const stats = await lstat(file);
    if (stats.isSymbolicLink()) throw new Error(`refusing symbolic-link config: ${file}`);
    if (!stats.isFile()) throw new Error(`config is not a regular file: ${file}`);
    return stats;
  } catch (error) {
    if (error?.code === "ENOENT") return undefined;
    throw error;
  }
}

async function physicalConfigDirectory(create) {
  const requested = configDirectory();
  if (create) await mkdir(requested, { recursive: true, mode: 0o700 });
  let directory;
  try {
    directory = await realpath(requested);
  } catch (error) {
    if (!create && error?.code === "ENOENT") return path.resolve(requested);
    throw error;
  }
  const stats = await lstat(directory);
  if (!stats.isDirectory()) throw new Error(`config path is not a directory: ${requested}`);
  return directory;
}

function parseConfig(text, file) {
  const errors = [];
  const config = parse(text, errors, { allowTrailingComma: true });
  if (errors.length > 0) {
    const first = errors[0];
    throw new Error(
      `invalid OpenCode config ${file}: ${printParseErrorCode(first.error)} at offset ${first.offset}`,
    );
  }
  if (!config || Array.isArray(config) || typeof config !== "object") {
    throw new Error(`OpenCode config must contain one object: ${file}`);
  }
  return config;
}

function isHarnessPlugin(entry) {
  const spec = Array.isArray(entry) ? entry[0] : entry;
  return (
    typeof spec === "string" &&
    (spec === PACKAGE_NAME || spec.startsWith(`${PACKAGE_NAME}@`))
  );
}

function formattingOptions(text) {
  const eol = text.includes("\r\n") ? "\r\n" : "\n";
  const indent = text.match(/(?:\r?\n)([ \t]+)["}]/)?.[1] ?? "  ";
  return {
    eol,
    insertSpaces: !indent.includes("\t"),
    tabSize: indent.includes("\t") ? 1 : indent.length,
  };
}

function configuredText(text, config, effectivePlugins) {
  if (config.plugin !== undefined && !Array.isArray(config.plugin)) {
    throw new Error("OpenCode config field 'plugin' must be an array");
  }
  if (effectivePlugins.some(isHarnessPlugin)) return undefined;
  const hasLocalPlugins = Array.isArray(config.plugin);
  const edits = modify(
    text,
    hasLocalPlugins ? ["plugin", config.plugin.length] : ["plugin"],
    hasLocalPlugins ? PACKAGE_NAME : [...effectivePlugins, PACKAGE_NAME],
    {
      formattingOptions: formattingOptions(text),
      isArrayInsertion: hasLocalPlugins,
    },
  );
  return applyEdits(text, edits);
}

function newConfigText() {
  return `${JSON.stringify({ $schema: SCHEMA_URL, plugin: [PACKAGE_NAME] }, null, 2)}\n`;
}

function timestamp() {
  return new Date().toISOString().replaceAll(":", "").replaceAll(".", "-");
}

function sameIdentity(first, second) {
  return first.dev === second.dev && first.ino === second.ino;
}

async function assertDestinationUnchanged(file, previousStats) {
  const current = await existingRegularFile(file);
  if (!previousStats) {
    if (current) throw new Error(`OpenCode config appeared during setup: ${file}`);
    return;
  }
  if (
    !current ||
    current.dev !== previousStats.dev ||
    current.ino !== previousStats.ino ||
    current.size !== previousStats.size ||
    current.mtimeMs !== previousStats.mtimeMs
  ) {
    throw new Error(`OpenCode config changed during setup: ${file}`);
  }
}

async function assertSourcesUnchanged(sources) {
  for (const source of sources) {
    await assertDestinationUnchanged(source.file, source.stats);
  }
}

async function assertDirectoryUnchanged(directory, openedStats) {
  const current = await lstat(directory);
  if (!current.isDirectory() || !sameIdentity(current, openedStats)) {
    throw new Error(`OpenCode config directory changed during setup: ${directory}`);
  }
}

async function publishConfig(
  file,
  previousStats,
  previousText,
  content,
  sources,
  expectedDirectoryStats,
) {
  const directory = path.dirname(file);
  const directoryHandle = await open(
    directory,
    constants.O_RDONLY | (process.platform === "win32" ? 0 : constants.O_DIRECTORY),
  );

  try {
    const openedDirectoryStats = await directoryHandle.stat();
    if (
      !openedDirectoryStats.isDirectory() ||
      !sameIdentity(openedDirectoryStats, expectedDirectoryStats)
    ) {
      throw new Error(`OpenCode config directory changed during setup: ${directory}`);
    }
    await assertDirectoryUnchanged(directory, openedDirectoryStats);
    await assertSourcesUnchanged(sources);

    let backup;
    if (previousStats) {
      backup = `${file}.before-oh-no-harness-${timestamp()}.bak`;
      const backupHandle = await open(
        backup,
        constants.O_WRONLY |
          constants.O_CREAT |
          constants.O_EXCL |
          (constants.O_NOFOLLOW ?? 0),
        0o600,
      );
      try {
        await backupHandle.writeFile(previousText, "utf8");
        await backupHandle.sync();
      } finally {
        await backupHandle.close();
      }
    }

    const temporary = `${file}.oh-no-harness-${process.pid}-${Date.now()}.tmp`;
    let renamed = false;
    try {
      const handle = await open(
        temporary,
        constants.O_WRONLY |
          constants.O_CREAT |
          constants.O_EXCL |
          (constants.O_NOFOLLOW ?? 0),
        0o600,
      );
      try {
        await handle.writeFile(content, "utf8");
        await handle.sync();
      } finally {
        await handle.close();
      }
      await assertDirectoryUnchanged(directory, openedDirectoryStats);
      await assertSourcesUnchanged(sources);
      await assertDestinationUnchanged(file, previousStats);
      await rename(temporary, file);
      renamed = true;
      if (process.platform !== "win32") await directoryHandle.sync();
    } finally {
      if (!renamed) await rm(temporary, { force: true }).catch(() => {});
    }
    return backup;
  } finally {
    await directoryHandle.close();
  }
}

async function readState(createDirectory = false) {
  const directory = await physicalConfigDirectory(createDirectory);
  let directoryStats;
  try {
    directoryStats = await lstat(directory);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  const entries = [];
  const sources = [];
  let effectivePlugins = [];

  for (const filename of CONFIG_FILENAMES) {
    const file = path.join(directory, filename);
    const stats = await existingRegularFile(file);
    if (!stats) {
      sources.push({ file, stats: undefined });
      continue;
    }
    const handle = await open(file, constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
    try {
      const openedStats = await handle.stat();
      if (
        !openedStats.isFile() ||
        openedStats.dev !== stats.dev ||
        openedStats.ino !== stats.ino
      ) {
        throw new Error(`OpenCode config changed during setup: ${file}`);
      }
      const text = await handle.readFile("utf8");
      const config = parseConfig(text, file);
      if (config.plugin !== undefined) {
        if (!Array.isArray(config.plugin)) {
          throw new Error(`OpenCode config field 'plugin' must be an array: ${file}`);
        }
        effectivePlugins = config.plugin;
      }
      sources.push({ file, stats: openedStats });
      entries.push({ file, stats: openedStats, text, config });
    } finally {
      await handle.close();
    }
  }

  const target = entries.at(-1) ?? {
    file: path.join(directory, "opencode.json"),
    stats: undefined,
    text: undefined,
    config: {},
  };
  return { directory, directoryStats, sources, ...target, effectivePlugins };
}

async function check() {
  const state = await readState();
  const configured = state.effectivePlugins.some(isHarnessPlugin);
  process.stdout.write(
    `STATUS: ${configured ? "configured" : "unconfigured"}\nCONFIG: ${state.file}\n`,
  );
  return configured ? 0 : 1;
}

async function setup() {
  const state = await readState(true);
  const content = state.text === undefined
    ? newConfigText()
    : configuredText(state.text, state.config, state.effectivePlugins);
  if (content === undefined) {
    process.stdout.write(
      `STATUS: already-configured\nCONFIG: ${state.file}\n${MODEL_SETUP_NEXT_STEP}\n`,
    );
    return 0;
  }
  const backup = await publishConfig(
    state.file,
    state.stats,
    state.text,
    content,
    state.sources,
    state.directoryStats,
  );
  process.stdout.write(
    [
      "STATUS: configured",
      `CONFIG: ${state.file}`,
      ...(backup ? [`BACKUP: ${backup}`] : []),
      "RESTART REQUIRED: quit and restart OpenCode to install and activate the plugin.",
      MODEL_SETUP_NEXT_STEP,
      "",
    ].join("\n"),
  );
  return 0;
}

async function main(args) {
  if (args[0] !== "setup" || args.length > 2 || (args[1] && args[1] !== "--check")) {
    process.stderr.write(`${usage()}\n`);
    return 2;
  }
  return args[1] === "--check" ? check() : setup();
}

try {
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`oh-no-harness setup: ${error.message}\n`);
  process.exitCode = 1;
}
