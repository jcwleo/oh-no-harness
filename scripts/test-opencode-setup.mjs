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
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const cli = process.argv[2];
if (!cli) throw new Error("usage: test-opencode-setup.mjs /path/to/setup.js");

const root = await mkdtemp(path.join(os.tmpdir(), "oh-no-opencode-setup-test-"));

function run(configDirectory, args = ["setup"], extraEnv = {}) {
  return spawnSync(process.execPath, [cli, ...args], {
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: path.join(root, "home"),
      OPENCODE_CONFIG_DIR: configDirectory,
      XDG_CONFIG_HOME: path.join(root, "xdg"),
      ...extraEnv,
    },
  });
}

function assertStatus(result, expected, label) {
  assert.equal(
    result.status,
    expected,
    `${label}: expected ${expected}, got ${result.status}\nstdout=${result.stdout}\nstderr=${result.stderr}`,
  );
}

try {
  const fresh = path.join(root, "fresh");
  let result = run(fresh, ["setup", "--check"]);
  assertStatus(result, 1, "fresh check");
  assert.match(result.stdout, /^STATUS: unconfigured$/mu);
  await assert.rejects(lstat(fresh), { code: "ENOENT" });

  result = run(fresh);
  assertStatus(result, 0, "fresh setup");
  assert.match(result.stdout, /^STATUS: configured$/mu);
  assert.match(result.stdout, /RESTART REQUIRED/u);
  assert.match(result.stdout, /quit any running OpenCode.*run \/configure-subagents/u);
  const freshConfig = path.join(fresh, "opencode.json");
  const freshText = await readFile(freshConfig, "utf8");
  assert.deepEqual(JSON.parse(freshText), {
    $schema: "https://opencode.ai/config.json",
    plugin: ["oh-no-harness"],
  });
  assert.equal((await lstat(freshConfig)).mode & 0o777, 0o600);

  result = run(fresh, ["setup", "--check"]);
  assertStatus(result, 0, "configured check");
  assert.match(result.stdout, /^STATUS: configured$/mu);

  result = run(fresh);
  assertStatus(result, 0, "idempotent setup");
  assert.match(result.stdout, /^STATUS: already-configured$/mu);
  assert.match(result.stdout, /quit any running OpenCode.*run \/configure-subagents/u);
  assert.equal(await readFile(freshConfig, "utf8"), freshText);
  assert.deepEqual((await readdir(fresh)).sort(), ["opencode.json"]);

  const jsonc = path.join(root, "jsonc");
  await mkdir(jsonc, { recursive: true });
  const jsoncFile = path.join(jsonc, "opencode.jsonc");
  const originalJsonc = [
    "{",
    "  // Keep this provider configuration byte-for-byte.",
    '  "provider": { "fixture": { "options": { "apiKey": "{env:FIXTURE_TOKEN}" } } },',
    '  "plugin": [',
    "    // Keep this plugin comment.",
    '    "existing-plugin",',
    "  ],",
    '  "model": "fixture/model",',
    "}",
    "",
  ].join("\n");
  await writeFile(jsoncFile, originalJsonc, { mode: 0o640 });
  result = run(jsonc);
  assertStatus(result, 0, "JSONC setup");
  const configuredJsonc = await readFile(jsoncFile, "utf8");
  assert.match(configuredJsonc, /Keep this provider configuration byte-for-byte/u);
  assert.match(configuredJsonc, /Keep this plugin comment/u);
  assert.match(configuredJsonc, /\{env:FIXTURE_TOKEN\}/u);
  assert.match(configuredJsonc, /"plugin": \[/u);
  assert.match(configuredJsonc, /"oh-no-harness"/u);
  assert.ok(configuredJsonc.indexOf('"existing-plugin"') < configuredJsonc.indexOf('"oh-no-harness"'));
  assert.equal((await lstat(jsoncFile)).mode & 0o777, 0o600);
  const jsoncEntries = await readdir(jsonc);
  const backups = jsoncEntries.filter((entry) => entry.includes(".before-oh-no-harness-"));
  assert.equal(backups.length, 1);
  assert.equal(await readFile(path.join(jsonc, backups[0]), "utf8"), originalJsonc);
  assert.equal((await lstat(path.join(jsonc, backups[0]))).mode & 0o777, 0o600);

  const both = path.join(root, "both");
  await mkdir(both, { recursive: true });
  const bothJson = path.join(both, "opencode.json");
  const bothJsonc = path.join(both, "opencode.jsonc");
  const legacyJson = path.join(both, "config.json");
  await writeFile(legacyJson, '{"plugin":["legacy-plugin"]}\n');
  await writeFile(bothJson, '{"model":"fixture/json","plugin":["middle-plugin"]}\n');
  await writeFile(bothJsonc, '{"model":"fixture/jsonc"}\n');
  result = run(both);
  assertStatus(result, 0, "global config precedence");
  assert.deepEqual(JSON.parse(await readFile(legacyJson, "utf8")).plugin, ["legacy-plugin"]);
  assert.deepEqual(JSON.parse(await readFile(bothJson, "utf8")).plugin, ["middle-plugin"]);
  assert.deepEqual(JSON.parse(await readFile(bothJsonc, "utf8")).plugin, [
    "middle-plugin",
    "oh-no-harness",
  ]);

  const pinned = path.join(root, "pinned");
  await mkdir(pinned, { recursive: true });
  const pinnedFile = path.join(pinned, "opencode.json");
  const pinnedText = '{"plugin":[["oh-no-harness@2.2.0",{"fixture":true}]]}\n';
  await writeFile(pinnedFile, pinnedText);
  result = run(pinned);
  assertStatus(result, 0, "pinned tuple setup");
  assert.match(result.stdout, /^STATUS: already-configured$/mu);
  assert.equal(await readFile(pinnedFile, "utf8"), pinnedText);

  for (const [name, invalid] of [
    ["invalid-json", '{"plugin": [}\n'],
    ["invalid-plugin", '{"plugin": "oh-no-harness"}\n'],
  ]) {
    const directory = path.join(root, name);
    await mkdir(directory, { recursive: true });
    const file = path.join(directory, "opencode.json");
    await writeFile(file, invalid);
    result = run(directory);
    assertStatus(result, 1, name);
    assert.equal(await readFile(file, "utf8"), invalid);
    assert.deepEqual((await readdir(directory)).sort(), ["opencode.json"]);
  }

  const linked = path.join(root, "linked");
  await mkdir(linked, { recursive: true });
  const target = path.join(linked, "target.json");
  await writeFile(target, '{"model":"fixture/model"}\n');
  await symlink(target, path.join(linked, "opencode.json"));
  result = run(linked);
  assertStatus(result, 1, "symlink config");
  assert.match(result.stderr, /refusing symbolic-link config/u);
  assert.equal(await readFile(target, "utf8"), '{"model":"fixture/model"}\n');

  result = run(fresh, ["setup", "--unknown"]);
  assertStatus(result, 2, "unknown option");
  assert.match(result.stderr, /^Usage: oh-no-harness setup \[--check\]$/mu);

  result = run(fresh, []);
  assertStatus(result, 2, "missing setup command");

  const xdgRoot = path.join(root, "explicit-xdg");
  result = run("", ["setup"], {
    OPENCODE_CONFIG_DIR: "",
    XDG_CONFIG_HOME: xdgRoot,
  });
  assertStatus(result, 0, "XDG setup");
  assert.deepEqual(
    JSON.parse(await readFile(path.join(xdgRoot, "opencode", "opencode.json"), "utf8")),
    { $schema: "https://opencode.ai/config.json", plugin: ["oh-no-harness"] },
  );

  console.log("PASS: OpenCode setup CLI fixtures");
} finally {
  await chmod(root, 0o700).catch(() => {});
  await rm(root, { recursive: true, force: true });
}
