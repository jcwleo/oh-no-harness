#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_ROOT="${OH_NO_PLUGIN_ROOT:-$REPO_ROOT/plugins/oh-no-harness}"
PLUGIN_INDEX="$PLUGIN_ROOT/opencode/index.js"
CONFIGURATOR="$PLUGIN_ROOT/opencode/configure-opencode-subagents"
CONFIGURE_TOOL="oh_no_configure_subagents"
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"
NODE_BIN="${NODE_BIN:-node}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

TEMP_ROOT=""

log() { printf '\n==> %s\n' "$*" >&2; }
ok() { printf 'ok - %s\n' "$*" >&2; }
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  [[ -z "$TEMP_ROOT" ]] || rm -rf "$TEMP_ROOT"
  exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

expect_status() {
  local expected="$1" output="$2" label="$3"
  shift 3
  local status=0
  "$@" >"$output" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] \
    || fail "$label returned $status instead of $expected (output: $output)"
}

run_opencode() {
  # Keep every invocation independent and serial. Concurrent first starts can
  # race OpenCode's SQLite migration.
  local config_dir="${OH_NO_TEST_OPENCODE_CONFIG_DIR:-$OPENCODE_CONFIG_DIR}"
  (
    cd "$PROJECT_ROOT"
    OPENCODE_CONFIG_DIR="$config_dir" "$OPENCODE_BIN" "$@"
  )
}

run_opencode_capture() {
  local output="$1"
  shift
  run_opencode "$@" >"$output" 2>&1
}

project_manifest() {
  "$PYTHON_BIN" - "$PROJECT_ROOT" <<'PY'
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
entries = []
for path in sorted(root.rglob("*"), key=lambda value: value.relative_to(root).as_posix()):
    relative = path.relative_to(root)
    if relative.parts and relative.parts[0] == ".git":
        continue
    info = path.lstat()
    if stat.S_ISREG(info.st_mode):
        entries.append([
            relative.as_posix(),
            "file",
            stat.S_IMODE(info.st_mode),
            hashlib.sha256(path.read_bytes()).hexdigest(),
        ])
    elif stat.S_ISDIR(info.st_mode):
        entries.append([relative.as_posix(), "dir", stat.S_IMODE(info.st_mode), ""])
    elif stat.S_ISLNK(info.st_mode):
        entries.append([relative.as_posix(), "link", 0, os.readlink(path)])
    else:
        entries.append([relative.as_posix(), "other", stat.S_IMODE(info.st_mode), ""])
print(json.dumps(entries, separators=(",", ":"), ensure_ascii=True))
PY
}

require_command "$OPENCODE_BIN"
require_command "$NODE_BIN"
require_command "$PYTHON_BIN"
require_command git

[[ -f "$PLUGIN_INDEX" ]] || fail "missing source OpenCode plugin: $PLUGIN_INDEX"
[[ -x "$CONFIGURATOR" ]] || fail "missing executable configurator: $CONFIGURATOR"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-opencode-test.XXXXXX")"
TEMP_ROOT="$($NODE_BIN -e 'console.log(require("node:fs").realpathSync(process.argv[1]))' "$TEMP_ROOT")"
export HOME="$TEMP_ROOT/home"
export XDG_CONFIG_HOME="$TEMP_ROOT/xdg-config"
export XDG_DATA_HOME="$TEMP_ROOT/xdg-data"
export XDG_CACHE_HOME="$TEMP_ROOT/xdg-cache"
export XDG_STATE_HOME="$TEMP_ROOT/xdg-state"
export OPENCODE_CONFIG_DIR="$TEMP_ROOT/opencode-config"
export OH_NO_CONFIG_DIR="$TEMP_ROOT/oh-no-config"
export OPENCODE_DISABLE_DEFAULT_PLUGINS=1
export OPENCODE_DISABLE_EXTERNAL_SKILLS=1
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1
export NO_COLOR=1
export TERM=dumb
unset OPENCODE_CONFIG OPENCODE_CONFIG_CONTENT OPENCODE_PURE

OPENCODE_VERSION="$($OPENCODE_BIN --version 2>&1)"
[[ "$OPENCODE_VERSION" == "1.18.14" ]] \
  || fail "this driver is pinned to opencode 1.18.14; found $OPENCODE_VERSION"

PROJECT_ROOT="$TEMP_ROOT/project"
CUSTOM_SKILLS_ROOT="$TEMP_ROOT/custom-skills"
mkdir -p \
  "$HOME" \
  "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" \
  "$XDG_CACHE_HOME" \
  "$XDG_STATE_HOME" \
  "$OPENCODE_CONFIG_DIR" \
  "$OH_NO_CONFIG_DIR" \
  "$PROJECT_ROOT" \
  "$CUSTOM_SKILLS_ROOT/custom-skill"

cat >"$CUSTOM_SKILLS_ROOT/custom-skill/SKILL.md" <<'EOF'
---
name: custom-skill
description: Disposable unrelated skill used by the OpenCode plugin driver.
---

# Custom Skill
EOF

cat >"$PROJECT_ROOT/sentinel.txt" <<'EOF'
OpenCode plugin test project sentinel.
EOF
git -C "$PROJECT_ROOT" init -q
git -C "$PROJECT_ROOT" config user.email opencode-test@example.invalid
git -C "$PROJECT_ROOT" config user.name "OpenCode Plugin Test"
git -C "$PROJECT_ROOT" add sentinel.txt
git -C "$PROJECT_ROOT" commit -qm "seed disposable project"

PLUGIN_URL="$($NODE_BIN -e 'console.log(require("node:url").pathToFileURL(process.argv[1]).href)' "$PLUGIN_INDEX")"
PLUGIN_ROOT_REAL="$($NODE_BIN -e 'console.log(require("node:fs").realpathSync(process.argv[1]))' "$PLUGIN_ROOT")"

PLUGIN_URL="$PLUGIN_URL" CUSTOM_SKILLS_ROOT="$CUSTOM_SKILLS_ROOT" \
  "$NODE_BIN" --input-type=module - "$OPENCODE_CONFIG_DIR/opencode.json" <<'NODE'
import { writeFile } from "node:fs/promises";

const configPath = process.argv[2];
const config = {
  "$schema": "https://opencode.ai/config.json",
  plugin: [process.env.PLUGIN_URL],
  default_agent: "build",
  subagent_depth: 1,
  skills: { paths: [process.env.CUSTOM_SKILLS_ROOT] },
  agent: {
    "custom-primary": {
      description: "Unrelated custom primary agent.",
      mode: "primary",
      prompt: "Remain unrelated.",
    },
    build: { description: "User build replacement.", temperature: 0.25 },
    plan: { description: "User plan replacement.", temperature: 0.5 },
  },
  command: {
    "custom-command": {
      description: "Unrelated custom command.",
      template: "Do nothing.",
    },
  },
};
await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
NODE

PROJECT_MANIFEST_BEFORE="$(project_manifest)"
PROJECT_STATUS_BEFORE="$(git -C "$PROJECT_ROOT" status --porcelain=v1 --untracked-files=all)"

log "Checking source identity, exact generated inventories, and config semantics"
TOOL_CONFIG_DIR="$TEMP_ROOT/tool-definition-execution" \
PLUGIN_URL="$PLUGIN_URL" PLUGIN_ROOT_REAL="$PLUGIN_ROOT_REAL" \
CUSTOM_SKILLS_ROOT="$CUSTOM_SKILLS_ROOT" PLUGIN_ROOT="$PLUGIN_ROOT" \
  "$NODE_BIN" --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const expectedAgents = [
  "oh-no",
  "oh-no-explore",
  "oh-no-analyst",
  "oh-no-planner",
  "oh-no-plan-reviewer",
  "oh-no-executor",
  "oh-no-debugger",
  "oh-no-verifier",
  "oh-no-code-reviewer",
  "oh-no-fusion-rescue-analyst",
];
const roles = [
  "explore",
  "analyst",
  "planner",
  "plan-reviewer",
  "executor",
  "debugger",
  "verifier",
  "code-reviewer",
  "fusion-rescue-analyst",
];
const expectedCommands = [
  "interview",
  "ralplan",
  "ralph",
  "ultrawork",
  "auto-routing",
  "test-driven-development",
  "simplify",
  "verification-before-completion",
  "systematic-debugging",
  "fusion-rescue",
  "configure-subagents",
];

function wildcardMatch(value, pattern) {
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");
  return new RegExp(`^${escaped}$`, "s").test(value);
}

function permissionAction(permission, tool, target = "*") {
  if (typeof permission === "string") return permission;
  let action;
  for (const [toolPattern, policy] of Object.entries(permission ?? {})) {
    if (!wildcardMatch(tool, toolPattern)) continue;
    if (typeof policy === "string") {
      action = policy;
      continue;
    }
    const candidate = Object.entries(policy ?? {})
      .findLast(([pattern]) => wildcardMatch(target, pattern))?.[1];
    if (candidate !== undefined) action = candidate;
  }
  return action;
}

function layeredPermissionAction(permissions, tool, target = "*") {
  let action;
  for (const permission of permissions) {
    const candidate = permissionAction(permission, tool, target);
    if (candidate !== undefined) action = candidate;
  }
  return action;
}

const agentsPath = path.join(process.env.PLUGIN_ROOT, "opencode/generated/agents.json");
const commandsPath = path.join(process.env.PLUGIN_ROOT, "opencode/generated/commands.json");
const generatedAgents = JSON.parse(await readFile(agentsPath, "utf8"));
const generatedCommands = JSON.parse(await readFile(commandsPath, "utf8"));
assert.deepEqual(Object.keys(generatedAgents), expectedAgents);
assert.deepEqual(Object.keys(generatedCommands), expectedCommands);

const skillRoot = path.join(process.env.PLUGIN_ROOT, "skills-opencode");
const skillInventory = [];
for (const entry of await readdir(skillRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const files = await readdir(path.join(skillRoot, entry.name));
  if (files.includes("SKILL.md")) skillInventory.push(entry.name);
}
assert.deepEqual(skillInventory.sort(), [...expectedCommands].sort());

assert.equal(generatedAgents["oh-no"].mode, "primary");
assert.deepEqual(generatedAgents["oh-no"].permission, {
  question: "allow",
  task: {
    "*": "deny",
    ...Object.fromEntries(roles.map((role) => [`oh-no-${role}`, "allow"])),
  },
  oh_no_get_model_catalog: "ask",
  oh_no_configure_subagents: "ask",
});
for (const role of roles) {
  const agent = generatedAgents[`oh-no-${role}`];
  assert.equal(agent.mode, "subagent");
  assert.equal(Object.hasOwn(agent, "model"), false);
  if (["planner", "executor"].includes(role)) {
    assert.equal(Object.hasOwn(agent.permission, "edit"), false);
  } else {
    assert.equal(agent.permission.edit, "deny");
  }
  if (["debugger", "verifier"].includes(role)) {
    assert.deepEqual(agent.permission.task, {
      "*": "deny",
      "oh-no-explore": "allow",
      "oh-no-analyst": "allow",
    });
  } else {
    assert.equal(agent.permission.task, "deny");
  }
  if (["analyst", "planner", "plan-reviewer", "code-reviewer", "fusion-rescue-analyst"].includes(role)) {
    assert.equal(agent.permission.bash, "deny");
  } else {
    assert.equal(Object.hasOwn(agent.permission, "bash"), false);
  }
  assert.equal(agent.permission.oh_no_get_model_catalog, "deny");
  assert.equal(agent.permission.oh_no_configure_subagents, "deny");
}
for (const [name, command] of Object.entries(generatedCommands)) {
  assert.equal(command.agent, "oh-no");
  assert.ok(command.template.includes("Load the `" + name + "` skill"));
  assert.ok(command.template.endsWith("$ARGUMENTS"));
}
assert.match(generatedCommands["configure-subagents"].template, /never treat arguments as confirmation/);
assert.match(generatedCommands["configure-subagents"].template, /bypass of its apply gate/);

const module = await import(process.env.PLUGIN_URL);
assert.equal(typeof module.default, "function");
const providerModels = Object.fromEntries(roles.map((role) => [role, {
  id: role,
  name: `Definition ${role}`,
  status: "active",
  variants: { high: {} },
}]));
const client = {
  config: {
    providers: async ({ query }) => {
      assert.deepEqual(query, { directory: "/definition/project" });
      return { data: { providers: [{ id: "definition-test", models: providerModels }] } };
    },
    get: async () => ({ data: { model: "definition-test/explore" } }),
  },
};
const hooks = await module.default({ client, directory: "/definition/project" });
assert.equal(typeof hooks.config, "function");
assert.equal(Object.hasOwn(hooks, "shell.env"), false);
assert.deepEqual(Object.keys(hooks.tool), ["oh_no_get_model_catalog", "oh_no_configure_subagents"]);
const catalogTool = hooks.tool.oh_no_get_model_catalog;
assert.deepEqual(Object.keys(catalogTool.args), ["mode", "provider", "cursor"]);
const catalogResult = JSON.parse(await catalogTool.execute({ mode: "providers", provider: "", cursor: "0" }));
assert.equal(catalogResult.status, "available");
assert.equal(catalogResult.primary_model, "definition-test/explore");
assert.deepEqual(catalogResult.providers, [{ id: "definition-test", model_count: roles.length }]);
assert.equal(catalogResult.featured_models.length, 1);
assert.deepEqual(catalogResult.featured_models[0].variants, ["default", "high"]);
const modelPage = JSON.parse(await catalogTool.execute({
  mode: "models", provider: "definition-test", cursor: "0",
}));
assert.equal(modelPage.models.length, roles.length);
assert.equal(modelPage.next_cursor, null);
const configureTool = hooks.tool.oh_no_configure_subagents;
assert.equal(typeof configureTool.execute, "function");
const expectedToolArgs = roles.flatMap((role) => [role, `${role}-variant`]);
assert.deepEqual(Object.keys(configureTool.args), expectedToolArgs);
const legacySchema = {
  type: "object",
  properties: configureTool.args,
  required: Object.keys(configureTool.args),
};
assert.deepEqual(legacySchema.required, expectedToolArgs);
for (const role of roles) {
  assert.equal(configureTool.args[role].type, "string");
  assert.equal(configureTool.args[role].pattern, "^[\\s\\S]+\\/[\\s\\S]+$");
  assert.equal(configureTool.args[`${role}-variant`].type, "string");
  assert.equal(configureTool.args[`${role}-variant`].pattern, "^[\\s\\S]+$");
}
const previousConfigDirectory = process.env.OH_NO_CONFIG_DIR;
process.env.OH_NO_CONFIG_DIR = process.env.TOOL_CONFIG_DIR;
let toolResult;
const toolArgs = Object.fromEntries(
  roles.flatMap((role) => [[role, `definition-test/${role}`], [`${role}-variant`, "high"]]),
);
const deniedRequest = [];
try {
  let staleAsked = false;
  const staleResult = await configureTool.execute(
    { ...toolArgs, analyst: "definition-test/no-longer-available" },
    { ask: async () => { staleAsked = true; } },
  );
  assert.equal(staleResult, "STATUS: invalid-assignments\nPreferences were not changed.");
  assert.equal(staleAsked, false);
  await assert.rejects(
    configureTool.execute(toolArgs, {
      ask: async (request) => {
        deniedRequest.push(request);
        throw new Error("host permission denied");
      },
    }),
    /host permission denied/u,
  );
  await assert.rejects(
    readFile(path.join(process.env.TOOL_CONFIG_DIR, "opencode-subagent-models.conf")),
    { code: "ENOENT" },
    "host permission denial did not block custom tool publication",
  );
  const allowedRequests = [];
  toolResult = await configureTool.execute(
    toolArgs,
    { ask: async (request) => allowedRequests.push(request) },
  );
  assert.equal(deniedRequest.length, 1);
  assert.equal(allowedRequests.length, 1);
  assert.deepEqual(allowedRequests[0], {
    permission: "oh_no_configure_subagents",
    patterns: ["*"],
    always: [],
    metadata: { operation: "configure-subagents", role_count: 9 },
  });
} finally {
  if (previousConfigDirectory === undefined) delete process.env.OH_NO_CONFIG_DIR;
  else process.env.OH_NO_CONFIG_DIR = previousConfigDirectory;
}
assert.match(toolResult, /^STATUS: configured$/mu);
assert.match(toolResult, /^RESTART REQUIRED:/mu);
const toolPreferences = await readFile(
  path.join(process.env.TOOL_CONFIG_DIR, "opencode-subagent-models.conf"),
  "utf8",
);
for (const role of roles) {
  assert.ok(toolPreferences.includes(
    `assignment={"role":"${role}","model":"definition-test/${role}","variant":"high"}\n`,
  ));
}

const config = {
  default_agent: "build",
  subagent_depth: 1,
  skills: { paths: [process.env.CUSTOM_SKILLS_ROOT], urls: ["https://example.invalid/skills"] },
  agent: {
    "custom-primary": { mode: "primary", prompt: "Remain unrelated." },
    build: { description: "User build replacement.", temperature: 0.25 },
    plan: { description: "User plan replacement.", temperature: 0.5 },
  },
  command: { "custom-command": { template: "Do nothing." } },
};
const globalPermission = { read: { "?x": "allow", "*x": "deny" } };
config.permission = globalPermission;
const globalPermissionBytes = JSON.stringify(globalPermission);
await hooks.config(config);
assert.strictEqual(config.permission, globalPermission);
assert.equal(JSON.stringify(config.permission), globalPermissionBytes);
assert.equal(config.default_agent, "oh-no");
assert.equal(config.subagent_depth, 2);
assert.deepEqual(config.agent.build, {
  description: "User build replacement.", temperature: 0.25, disable: true,
});
assert.deepEqual(config.agent.plan, {
  description: "User plan replacement.", temperature: 0.5, disable: true,
});
assert.equal(config.agent["custom-primary"].prompt, "Remain unrelated.");
assert.equal(config.command["custom-command"].template, "Do nothing.");
assert.equal(config.skills.urls[0], "https://example.invalid/skills");
assert.equal(config.skills.paths[0], process.env.CUSTOM_SKILLS_ROOT);
assert.equal(config.skills.paths.length, 2);
assert.equal(config.skills.paths[1], path.join(process.env.PLUGIN_ROOT_REAL, "skills-opencode"));
for (const name of expectedAgents) assert.ok(Object.hasOwn(config.agent, name));
for (const name of expectedCommands) assert.ok(Object.hasOwn(config.command, name));
for (const role of roles) assert.equal(Object.hasOwn(config.agent[`oh-no-${role}`], "model"), false);
assert.equal(config.agent["oh-no"].permission.question, "allow");
assert.equal(config.agent["oh-no"].permission.oh_no_get_model_catalog, "ask");
assert.equal(config.agent["oh-no"].permission.oh_no_configure_subagents, "ask");
assert.equal(Object.hasOwn(config.agent["oh-no"].permission, "bash"), false);
assert.deepEqual(config.agent["oh-no"].permission.task, {
  "*": "deny",
  ...Object.fromEntries(roles.map((role) => [`oh-no-${role}`, "allow"])),
});

const restricted = {
  permission: {
    "*": "allow",
    question: "ask",
    edit: "deny",
    task: { "*": "deny" },
    bash: "deny",
    oh_no_get_model_catalog: "deny",
    oh_no_configure_subagents: "deny",
  },
};
await hooks.config(restricted);
assert.equal(restricted.agent["oh-no"].permission.question, "ask");
for (const role of ["planner", "executor"]) {
  assert.equal(restricted.agent[`oh-no-${role}`].permission.edit, "deny");
}
for (const name of ["oh-no", "oh-no-debugger", "oh-no-verifier"]) {
  const task = restricted.agent[name].permission.task;
  for (const action of typeof task === "string" ? [task] : Object.values(task)) {
    assert.equal(action, "deny");
  }
}
for (const name of expectedAgents) {
  const bash = restricted.agent[name].permission.bash;
  if (bash !== undefined) assert.equal(bash, "deny");
  assert.equal(restricted.agent[name].permission.oh_no_configure_subagents, "deny");
  assert.equal(restricted.agent[name].permission.oh_no_get_model_catalog, "deny");
}

const perAgentRestricted = {
  agent: {
    "oh-no": {
      description: "User description must not replace the package description.",
      mode: "subagent",
      prompt: "User prompt must not replace the package prompt.",
      permission: {
        question: "deny",
        task: "deny",
        bash: "deny",
        oh_no_configure_subagents: "deny",
      },
    },
    "oh-no-executor": {
      description: "User executor description must not replace the package description.",
      mode: "primary",
      prompt: "User executor prompt must not replace the package prompt.",
      permission: { edit: "deny", oh_no_configure_subagents: "ask" },
    },
  },
};
await hooks.config(perAgentRestricted);
assert.equal(perAgentRestricted.agent["oh-no"].permission.question, "deny");
assert.equal(perAgentRestricted.agent["oh-no"].permission.task, "deny");
assert.equal(perAgentRestricted.agent["oh-no"].permission.bash, "deny");
assert.equal(perAgentRestricted.agent["oh-no"].permission.oh_no_configure_subagents, "deny");
assert.equal(perAgentRestricted.agent["oh-no-executor"].permission.edit, "deny");
assert.equal(perAgentRestricted.agent["oh-no-executor"].permission.oh_no_configure_subagents, "deny");
assert.equal(perAgentRestricted.agent["oh-no"].description, generatedAgents["oh-no"].description);
assert.equal(perAgentRestricted.agent["oh-no"].mode, generatedAgents["oh-no"].mode);
assert.equal(perAgentRestricted.agent["oh-no"].prompt, generatedAgents["oh-no"].prompt);
assert.equal(
  perAgentRestricted.agent["oh-no-executor"].description,
  generatedAgents["oh-no-executor"].description,
);
assert.equal(perAgentRestricted.agent["oh-no-executor"].mode, generatedAgents["oh-no-executor"].mode);
assert.equal(perAgentRestricted.agent["oh-no-executor"].prompt, generatedAgents["oh-no-executor"].prompt);

const primaryCeiling = {
  agent: {
    "oh-no": {
      permission: {
        edit: "deny",
        bash: "ask",
        task: "deny",
        read: "deny",
        "custom-tool": "deny",
        external_directory: {
          "*": "ask",
          "~/public/**": "allow",
          "~/private/**": "deny",
        },
        oh_no_configure_subagents: "deny",
      },
    },
  },
};
await hooks.config(primaryCeiling);
for (const name of expectedAgents) {
  const permission = primaryCeiling.agent[name].permission;
  assert.equal(permission.edit, "deny", `${name} escaped the primary edit ceiling`);
  assert.ok(["ask", "deny"].includes(permission.bash), `${name} escaped the primary Bash ceiling`);
  assert.equal(permission.task, "deny", `${name} escaped the primary task ceiling`);
  assert.equal(permission.read, "deny", `${name} escaped the primary read ceiling`);
  assert.equal(permission["custom-tool"], "deny", `${name} dropped the primary custom-tool ceiling`);
  assert.deepEqual(permission.external_directory, {
    "*": "ask",
    "~/private/**": "deny",
  });
  assert.equal(permission.oh_no_configure_subagents, "deny");
}

const roleSpecificCeiling = {
  agent: {
    "oh-no": { permission: { read: "ask", bash: "ask", "mcp-*": "ask" } },
    "oh-no-executor": {
      permission: {
        read: "deny",
        bash: "deny",
        webfetch: "deny",
        "mcp-public": "allow",
        "mcp-secret": "deny",
      },
    },
  },
};
await hooks.config(roleSpecificCeiling);
assert.equal(roleSpecificCeiling.agent["oh-no-planner"].permission.read, "ask");
assert.equal(roleSpecificCeiling.agent["oh-no-executor"].permission.read, "deny");
assert.equal(roleSpecificCeiling.agent["oh-no-executor"].permission.bash, "deny");
assert.equal(roleSpecificCeiling.agent["oh-no-executor"].permission.webfetch, "deny");
assert.equal(
  permissionAction(roleSpecificCeiling.agent["oh-no-executor"].permission, "mcp-public"),
  "ask",
);
assert.equal(
  permissionAction(roleSpecificCeiling.agent["oh-no-executor"].permission, "mcp-secret"),
  "deny",
);
assert.equal(
  Object.hasOwn(roleSpecificCeiling.agent["oh-no-executor"].permission, "mcp-public"),
  false,
);
assert.equal(
  Object.values(roleSpecificCeiling.agent["oh-no-executor"].permission).includes("allow"),
  false,
);

const globalPrimaryConflict = {
  permission: { read: "deny", bash: "deny" },
  agent: {
    "oh-no": { permission: { read: "ask", bash: "ask" } },
  },
};
await hooks.config(globalPrimaryConflict);
for (const name of expectedAgents) {
  const permission = globalPrimaryConflict.agent[name].permission;
  assert.equal(permission.read, "deny", `${name} weakened global read deny`);
  assert.equal(permission.bash, "deny", `${name} weakened global Bash deny`);
}

for (const [layer, candidate, affected] of [
  ["global", { permission: { "mcp-a*": "deny", "mcp-a?": "allow" } }, expectedAgents],
  [
    "primary",
    { agent: { "oh-no": { permission: { "mcp-a*": "deny", "mcp-a?": "allow" } } } },
    expectedAgents,
  ],
  [
    "role",
    { agent: { "oh-no-executor": { permission: { "mcp-a*": "deny", "mcp-a?": "allow" } } } },
    ["oh-no-executor"],
  ],
]) {
  await hooks.config(candidate);
  for (const name of affected) {
    const permission = candidate.agent[name].permission;
    assert.equal(layeredPermissionAction([candidate.permission, permission], "mcp-ab"), "deny", `${layer}/${name} overlap escaped conservative deny`);
    assert.equal(layeredPermissionAction([candidate.permission, permission], "mcp-abx"), "deny", `${layer}/${name} star-only region escaped`);
    assert.equal(layeredPermissionAction([candidate.permission, permission], "mcp-z"), undefined, `${layer}/${name} nonmatch was restricted`);
  }
  if (layer === "role") {
    assert.equal(permissionAction(candidate.agent["oh-no-planner"].permission, "mcp-abx"), undefined);
  }
}

for (const [layer, candidate, affected] of [
  ["global", { permission: { read: { "?x": "allow", "*x": "deny" } } }, expectedAgents],
  [
    "primary",
    { agent: { "oh-no": { permission: { read: { "?x": "allow", "*x": "deny" } } } } },
    expectedAgents,
  ],
  [
    "role",
    { agent: { "oh-no-executor": { permission: { read: { "?x": "allow", "*x": "deny" } } } } },
    ["oh-no-executor"],
  ],
]) {
  await hooks.config(candidate);
  for (const name of affected) {
    assert.equal(layeredPermissionAction([candidate.permission, candidate.agent[name].permission], "read", "x"), "deny", `${layer}/${name} nested target overlap escaped`);
  }
}

for (const [layer, candidate, affected] of [
  ["global", { permission: { "b*": "deny", "*": { zzz: "allow" } } }, expectedAgents],
  [
    "primary",
    { agent: { "oh-no": { permission: { "b*": "deny", "*": { zzz: "allow" } } } } },
    expectedAgents,
  ],
  [
    "role",
    { agent: { "oh-no-executor": { permission: { "b*": "deny", "*": { zzz: "allow" } } } } },
    ["oh-no-executor"],
  ],
]) {
  await hooks.config(candidate);
  for (const name of affected) {
    assert.equal(layeredPermissionAction([candidate.permission, candidate.agent[name].permission], "bash", "git status"), "deny", `${layer}/${name} later nonmatching inner target erased Bash deny`);
  }
}

const perAgentAsk = {
  agent: {
    "oh-no": { permission: { question: "ask", task: "ask", bash: "ask" } },
    "oh-no-executor": { permission: { edit: "ask" } },
  },
};
await hooks.config(perAgentAsk);
assert.equal(perAgentAsk.agent["oh-no"].permission.question, "ask");
for (const action of Object.values(perAgentAsk.agent["oh-no"].permission.task)) {
  assert.ok(["deny", "ask"].includes(action));
}
assert.equal(perAgentAsk.agent["oh-no"].permission.bash, "ask");
assert.equal(perAgentAsk.agent["oh-no-executor"].permission.edit, "ask");

const ambiguousRestrictions = {
  agent: {
    "oh-no": {
      permission: {
        "mcp-a*": { "*": "ask", secret: "deny" },
        "mcp-*": { "*": "ask", private: "deny" },
      },
    },
  },
};
await hooks.config(ambiguousRestrictions);
for (const toolPattern of ["mcp-a*", "mcp-*"]) {
  const policy = ambiguousRestrictions.agent["oh-no-executor"].permission[toolPattern];
  assert.deepEqual(Object.keys(policy), toolPattern === "mcp-a*" ? ["*", "secret"] : ["*", "private"]);
  assert.ok(Object.values(policy).every((action) => action === "deny"));
}

const ordered = { permission: { question: "deny", "*": "ask" } };
await hooks.config(ordered);
assert.equal(ordered.agent["oh-no"].permission.question, "ask");

for (const replacedDefault of [undefined, "build", "plan"]) {
  const candidate = {};
  if (replacedDefault !== undefined) candidate.default_agent = replacedDefault;
  await hooks.config(candidate);
  assert.equal(candidate.default_agent, "oh-no");
}
const preserved = { default_agent: "custom-primary", subagent_depth: 4 };
await hooks.config(preserved);
assert.equal(preserved.default_agent, "custom-primary");
assert.equal(preserved.subagent_depth, 4);

const gatePath = path.join(skillRoot, "configure-subagents/SKILL.md");
const gate = await readFile(gatePath, "utf8");
const normalizedGate = gate.replace(/\s+/gu, " ");
for (const signal of [
  "<HARD-GATE>",
  "current user request explicitly",
  "before calling `question`, `oh_no_get_model_catalog`,",
  "Call `oh_no_get_model_catalog` exactly once",
  "There are no fast, balanced, deep, preset, or quality profiles",
  "`Apply`, `Edit roles`, or `Cancel`",
  "call `oh_no_configure_subagents` exactly once",
  "Do not use Bash, a subprocess, `opencode models`",
  "restart OpenCode",
]) assert.ok(normalizedGate.includes(signal), `missing configurator hard-gate signal: ${signal}`);
NODE
ok "source file URL, plugin root identity, exact inventories, permissions, defaults, and hard gate"

log "Checking resolved OpenCode host inheritance and restrictive ceilings"
PERMISSION_FIXTURE_ROOT="$TEMP_ROOT/permission-fixtures"
mkdir -p "$PERMISSION_FIXTURE_ROOT"
PLUGIN_URL="$PLUGIN_URL" PERMISSION_FIXTURE_ROOT="$PERMISSION_FIXTURE_ROOT" \
  "$NODE_BIN" --input-type=module <<'NODE'
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const fixtures = {
  default: {},
  "question-deny": { permission: { question: "deny" } },
  "question-ask": { permission: { question: "ask" } },
  "wildcard-ask": { permission: { question: "deny", "*": "ask" } },
  "permission-string-deny": { permission: "deny" },
  "bash-allow": { permission: { bash: "allow" } },
  restricted: {
    permission: {
      edit: "deny",
      task: "deny",
      bash: "deny",
      oh_no_configure_subagents: "deny",
    },
  },
  "global-custom-ask": {
    permission: { oh_no_configure_subagents: "ask" },
  },
  "agent-restricted": {
    agent: {
      "oh-no": { permission: { question: "deny", task: "deny", bash: "deny" } },
      "oh-no-executor": { permission: { edit: "deny" } },
    },
  },
  "agent-custom-ask": {
    agent: {
      "oh-no": { permission: { oh_no_configure_subagents: "ask" } },
      "oh-no-executor": { permission: { oh_no_configure_subagents: "ask" } },
    },
  },
  "agent-custom-deny": {
    agent: {
      "oh-no": { permission: { oh_no_configure_subagents: "deny" } },
    },
  },
  "primary-ceiling": {
    agent: {
      "oh-no": {
        permission: {
          edit: "deny",
          bash: "ask",
          task: "deny",
          read: "deny",
          "custom-tool": "deny",
        },
      },
    },
  },
  "role-specific-deny": {
    agent: {
      "oh-no": { permission: { read: "ask", bash: "ask" } },
      "oh-no-executor": { permission: { read: "deny", bash: "deny", webfetch: "deny" } },
    },
  },
  "global-primary-conflict": {
    permission: { read: "deny", bash: "deny" },
    agent: {
      "oh-no": { permission: { read: "ask", bash: "ask" } },
    },
  },
  "wildcard-overlap-global": {
    permission: { "mcp-a*": "deny", "mcp-a?": "allow" },
  },
  "wildcard-overlap-primary": {
    agent: {
      "oh-no": { permission: { "mcp-a*": "deny", "mcp-a?": "allow" } },
    },
  },
  "wildcard-overlap-role": {
    agent: {
      "oh-no-executor": { permission: { "mcp-a*": "deny", "mcp-a?": "allow" } },
    },
  },
  "nested-target-overlap-global": {
    permission: { read: { "?x": "allow", "*x": "deny" } },
  },
  "nested-target-overlap-primary": {
    agent: {
      "oh-no": { permission: { read: { "?x": "allow", "*x": "deny" } } },
    },
  },
  "nested-target-overlap-role": {
    agent: {
      "oh-no-executor": { permission: { read: { "?x": "allow", "*x": "deny" } } },
    },
  },
  "outer-inner-overlap-global": {
    permission: { "b*": "deny", "*": { zzz: "allow" } },
  },
  "outer-inner-overlap-primary": {
    agent: {
      "oh-no": { permission: { "b*": "deny", "*": { zzz: "allow" } } },
    },
  },
  "outer-inner-overlap-role": {
    agent: {
      "oh-no-executor": { permission: { "b*": "deny", "*": { zzz: "allow" } } },
    },
  },
  "native-global-output": {
    plugin: [],
    permission: {
      "mcp-a*": "deny",
      "mcp-a?": "allow",
      read: { "?x": "allow", "*x": "deny" },
      "b*": "deny",
      "*": { zzz: "allow" },
    },
    agent: {
      "native-probe": {
        description: "Permission-only host output probe.",
        mode: "primary",
        prompt: "Do not run; this agent exists only for debug output.",
      },
    },
  },
};
for (const [name, fixture] of Object.entries(fixtures)) {
  const directory = path.join(process.env.PERMISSION_FIXTURE_ROOT, name);
  await mkdir(directory, { recursive: true });
  const config = {
    "$schema": "https://opencode.ai/config.json",
    plugin: [process.env.PLUGIN_URL],
  };
  Object.assign(config, fixture);
  await writeFile(
    path.join(directory, "opencode.json"),
    `${JSON.stringify(config, null, 2)}\n`,
    "utf8",
  );
}
NODE

run_opencode_fixture_capture() {
  local config_dir="$1" output="$2"
  shift 2
  OH_NO_TEST_OPENCODE_CONFIG_DIR="$config_dir" run_opencode "$@" >"$output" 2>&1
}

for name in \
  oh-no oh-no-explore oh-no-analyst oh-no-planner oh-no-plan-reviewer \
  oh-no-executor oh-no-debugger oh-no-verifier oh-no-code-reviewer \
  oh-no-fusion-rescue-analyst; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/default" \
    "$TEMP_ROOT/permission-default-$name.json" \
    debug agent "$name"
done
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/question-deny" \
  "$TEMP_ROOT/permission-question-deny.json" \
  debug agent oh-no
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/question-ask" \
  "$TEMP_ROOT/permission-question-ask.json" \
  debug agent oh-no
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/wildcard-ask" \
  "$TEMP_ROOT/permission-wildcard-ask.json" \
  debug agent oh-no
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/permission-string-deny" \
  "$TEMP_ROOT/permission-string-deny.json" \
  debug agent oh-no
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/native-global-output" \
  "$TEMP_ROOT/permission-native-global-output.json" \
  debug agent native-probe
for name in oh-no oh-no-planner oh-no-executor oh-no-debugger oh-no-verifier; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/restricted" \
    "$TEMP_ROOT/permission-restricted-$name.json" \
    debug agent "$name"
done
for name in oh-no oh-no-executor; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/bash-allow" \
    "$TEMP_ROOT/permission-bash-allow-$name.json" \
    debug agent "$name"
done
for name in oh-no oh-no-executor; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/agent-restricted" \
    "$TEMP_ROOT/permission-agent-restricted-$name.json" \
    debug agent "$name"
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/agent-custom-ask" \
    "$TEMP_ROOT/permission-agent-custom-ask-$name.json" \
    debug agent "$name"
done
run_opencode_fixture_capture \
  "$PERMISSION_FIXTURE_ROOT/agent-custom-deny" \
  "$TEMP_ROOT/permission-agent-custom-deny-oh-no.json" \
  debug agent oh-no
for name in oh-no oh-no-executor; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/global-custom-ask" \
    "$TEMP_ROOT/permission-global-custom-ask-$name.json" \
    debug agent "$name"
done
for name in \
  oh-no oh-no-explore oh-no-analyst oh-no-planner oh-no-plan-reviewer \
  oh-no-executor oh-no-debugger oh-no-verifier oh-no-code-reviewer \
  oh-no-fusion-rescue-analyst; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/primary-ceiling" \
    "$TEMP_ROOT/permission-primary-ceiling-$name.json" \
    debug agent "$name"
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/global-primary-conflict" \
    "$TEMP_ROOT/permission-global-primary-conflict-$name.json" \
    debug agent "$name"
done
for name in oh-no-planner oh-no-executor; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/role-specific-deny" \
    "$TEMP_ROOT/permission-role-specific-deny-$name.json" \
    debug agent "$name"
done
for family in nested-target-overlap outer-inner-overlap; do
  for scope in global primary; do
    for name in \
      oh-no oh-no-explore oh-no-analyst oh-no-planner oh-no-plan-reviewer \
      oh-no-executor oh-no-debugger oh-no-verifier oh-no-code-reviewer \
      oh-no-fusion-rescue-analyst; do
      run_opencode_fixture_capture \
        "$PERMISSION_FIXTURE_ROOT/$family-$scope" \
        "$TEMP_ROOT/permission-$family-$scope-$name.json" \
        debug agent "$name"
    done
  done
  for name in oh-no-explore oh-no-executor; do
    run_opencode_fixture_capture \
      "$PERMISSION_FIXTURE_ROOT/$family-role" \
      "$TEMP_ROOT/permission-$family-role-$name.json" \
      debug agent "$name"
  done
done
for scope in global primary; do
  for name in \
    oh-no oh-no-explore oh-no-analyst oh-no-planner oh-no-plan-reviewer \
    oh-no-executor oh-no-debugger oh-no-verifier oh-no-code-reviewer \
    oh-no-fusion-rescue-analyst; do
    run_opencode_fixture_capture \
      "$PERMISSION_FIXTURE_ROOT/wildcard-overlap-$scope" \
      "$TEMP_ROOT/permission-wildcard-overlap-$scope-$name.json" \
      debug agent "$name"
  done
done
for name in oh-no-planner oh-no-executor; do
  run_opencode_fixture_capture \
    "$PERMISSION_FIXTURE_ROOT/wildcard-overlap-role" \
    "$TEMP_ROOT/permission-wildcard-overlap-role-$name.json" \
    debug agent "$name"
done

"$PYTHON_BIN" - "$TEMP_ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
roles = [
    "explore", "analyst", "planner", "plan-reviewer", "executor", "debugger",
    "verifier", "code-reviewer", "fusion-rescue-analyst",
]


def load(name):
    path = root / name
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        raise SystemExit(f"invalid debug agent output {path}: {error}") from error


def matches(value, pattern):
    escaped = re.escape(pattern).replace(r"\*", ".*").replace(r"\?", ".")
    if escaped.endswith(r"\ \.\*"):
        escaped = escaped[:-6] + r"(?: .*)?"
    return re.fullmatch(escaped, value, flags=re.DOTALL) is not None


def action(agent, permission, pattern="*"):
    result = None
    for rule in agent["permission"]:
        if matches(permission, rule["permission"]) and matches(pattern, rule["pattern"]):
            result = rule["action"]
    return result


default = {name: load(f"permission-default-{name}.json") for name in ["oh-no", *(f"oh-no-{role}" for role in roles)]}
if action(default["oh-no"], "question") != "allow" or not default["oh-no"]["tools"]["question"]:
    raise SystemExit("default oh-no question permission did not resolve to allow/true")
if action(default["oh-no"], "oh_no_configure_subagents") != "ask":
    raise SystemExit("default oh-no custom configurator permission did not resolve to ask")
if not default["oh-no"]["tools"]["oh_no_configure_subagents"]:
    raise SystemExit("default oh-no custom configurator tool is not visible")
for role in roles:
    agent = default[f"oh-no-{role}"]
    if action(agent, "oh_no_configure_subagents") != "deny":
        raise SystemExit(f"oh-no-{role} custom configurator permission did not resolve to deny")
    if agent["tools"]["oh_no_configure_subagents"]:
        raise SystemExit(f"oh-no-{role} custom configurator tool unexpectedly remained visible")

for role in roles:
    expected = "allow"
    if action(default["oh-no"], "task", f"oh-no-{role}") != expected:
        raise SystemExit(f"default oh-no task edge to oh-no-{role} did not resolve to {expected}")
if action(default["oh-no"], "task", "oh-no-unregistered") != "deny":
    raise SystemExit("default oh-no task topology permits an unregistered package-like target")
for name in ("oh-no-debugger", "oh-no-verifier"):
    for target in ("oh-no-explore", "oh-no-analyst"):
        if action(default[name], "task", target) != "allow":
            raise SystemExit(f"{name} lost its bounded task edge to {target}")
    if action(default[name], "task", "oh-no-executor") != "deny":
        raise SystemExit(f"{name} broadened task access beyond its package role")

deny_bash = {
    "oh-no-analyst", "oh-no-planner", "oh-no-plan-reviewer",
    "oh-no-code-reviewer", "oh-no-fusion-rescue-analyst",
}
for name in deny_bash:
    if action(default[name], "bash", "git status") != "deny" or default[name]["tools"]["bash"]:
        raise SystemExit(f"{name} Bash class did not resolve to deny/false")
host_bash = action(default["oh-no"], "bash", "git status")
host_bash_tool = default["oh-no"]["tools"]["bash"]
for name in ("oh-no-explore", "oh-no-executor", "oh-no-debugger", "oh-no-verifier"):
    if action(default[name], "bash", "git status") != host_bash:
        raise SystemExit(f"{name} Bash did not inherit the host policy/default")
    if default[name]["tools"]["bash"] != host_bash_tool:
        raise SystemExit(f"{name} Bash visibility did not inherit the host policy/default")

host_edit = action(default["oh-no"], "edit", "fixture.txt")
for name in ("oh-no-planner", "oh-no-executor"):
    if action(default[name], "edit", "fixture.txt") != host_edit:
        raise SystemExit(f"{name} edit did not inherit the host policy/default")

if action(load("permission-question-deny.json"), "question") != "deny":
    raise SystemExit("explicit global question deny was overridden")
if action(load("permission-question-ask.json"), "question") != "ask":
    raise SystemExit("explicit global question ask was overridden")
if action(load("permission-wildcard-ask.json"), "question") != "ask":
    raise SystemExit("ordered top-level wildcard ask was not preserved for question")
if action(load("permission-string-deny.json"), "question") != "deny":
    raise SystemExit("top-level permission string deny was overridden for question")

restricted = {
    name: load(f"permission-restricted-{name}.json")
    for name in ("oh-no", "oh-no-planner", "oh-no-executor", "oh-no-debugger", "oh-no-verifier")
}
for name in ("oh-no-planner", "oh-no-executor"):
    if action(restricted[name], "edit", "fixture.txt") != "deny":
        raise SystemExit(f"global edit deny was overridden by {name}")
for name in ("oh-no", "oh-no-debugger", "oh-no-verifier"):
    for target in ("oh-no-explore", "oh-no-analyst"):
        if action(restricted[name], "task", target) != "deny":
            raise SystemExit(f"global task deny was overridden by {name} for {target}")
for name, agent in restricted.items():
    if action(agent, "bash", "git status") != "deny":
        raise SystemExit(f"global Bash deny was overridden by {name}")
    if action(agent, "oh_no_configure_subagents") != "deny":
        raise SystemExit(f"global custom-tool deny was overridden by {name}")

for name in ("oh-no", "oh-no-executor"):
    agent = load(f"permission-bash-allow-{name}.json")
    if action(agent, "bash", "git status") != "allow":
        raise SystemExit(f"global Bash allow did not preserve ordinary Bash for {name}")
agent_restricted = {
    name: load(f"permission-agent-restricted-{name}.json")
    for name in ("oh-no", "oh-no-executor")
}
for permission in ("question", "task", "bash"):
    target = "oh-no-explore" if permission == "task" else "git status" if permission == "bash" else "*"
    if action(agent_restricted["oh-no"], permission, target) != "deny":
        raise SystemExit(f"same-name oh-no per-agent {permission} deny was overridden")
if action(agent_restricted["oh-no-executor"], "edit", "fixture.txt") != "deny":
    raise SystemExit("same-name oh-no-executor per-agent edit deny was overridden")

for scope in ("global", "agent"):
    for name in ("oh-no", "oh-no-executor"):
        agent = load(f"permission-{scope}-custom-ask-{name}.json")
        expected = "ask" if name == "oh-no" else "deny"
        if action(agent, "oh_no_configure_subagents") != expected:
            raise SystemExit(
                f"{scope} custom-tool ask did not intersect package policy for {name}"
            )
if action(load("permission-agent-custom-deny-oh-no.json"), "oh_no_configure_subagents") != "deny":
    raise SystemExit("same-name per-agent custom-tool deny was overridden")

primary_ceiling = {
    name: load(f"permission-primary-ceiling-{name}.json")
    for name in ["oh-no", *(f"oh-no-{role}" for role in roles)]
}
package_bash_deny = {
    "oh-no-analyst", "oh-no-planner", "oh-no-plan-reviewer",
    "oh-no-code-reviewer", "oh-no-fusion-rescue-analyst",
}
for name, agent in primary_ceiling.items():
    for permission in ("edit", "task", "read", "custom-tool"):
        target = "oh-no-explore" if permission == "task" else "fixture.txt"
        if action(agent, permission, target) != "deny":
            raise SystemExit(f"{name} escaped primary {permission} deny")
    expected_bash = "deny" if name in package_bash_deny else "ask"
    if action(agent, "bash", "git status") != expected_bash:
        raise SystemExit(f"{name} did not intersect primary Bash ask with package policy")

for name in primary_ceiling:
    agent = load(f"permission-global-primary-conflict-{name}.json")
    if action(agent, "read", "fixture.txt") != "deny":
        raise SystemExit(f"{name} weakened global read deny through primary ask")
    if action(agent, "bash", "git status") != "deny":
        raise SystemExit(f"{name} weakened global Bash deny through primary ask")

role_planner = load("permission-role-specific-deny-oh-no-planner.json")
role_executor = load("permission-role-specific-deny-oh-no-executor.json")
if action(role_planner, "read", "fixture.txt") != "ask":
    raise SystemExit("primary read ask did not propagate to an unrestricted role")
for permission in ("read", "bash", "webfetch"):
    target = "git status" if permission == "bash" else "fixture.txt"
    if action(role_executor, permission, target) != "deny":
        raise SystemExit(f"role-specific executor {permission} deny was overridden")

for scope in ("global", "primary"):
    for name in ["oh-no", *(f"oh-no-{role}" for role in roles)]:
        agent = load(f"permission-wildcard-overlap-{scope}-{name}.json")
        expected_overlap = "deny"
        if action(agent, "mcp-ab") != expected_overlap:
            raise SystemExit(
                f"{scope}/{name} overlapping star/question region changed from {expected_overlap}"
            )
        if action(agent, "mcp-abx") != "deny":
            raise SystemExit(f"{scope}/{name} star-only region escaped deny")
        if action(agent, "mcp-z") != "allow":
            raise SystemExit(f"{scope}/{name} nonmatching MCP tool did not retain host allow")

role_overlap = load("permission-wildcard-overlap-role-oh-no-executor.json")
if action(role_overlap, "mcp-ab") != "deny" or action(role_overlap, "mcp-abx") != "deny":
    raise SystemExit("role-specific overlapping star/question policy escaped deny")
if action(role_overlap, "mcp-z") != "allow":
    raise SystemExit("role-specific nonmatching MCP tool did not retain host allow")
role_nonmatch = load("permission-wildcard-overlap-role-oh-no-planner.json")
for tool in ("mcp-ab", "mcp-abx", "mcp-z"):
    if action(role_nonmatch, tool) != "allow":
        raise SystemExit(f"role-specific wildcard policy leaked to planner for {tool}")

for scope in ("global", "primary"):
    for name in ["oh-no", *(f"oh-no-{role}" for role in roles)]:
        agent = load(f"permission-nested-target-overlap-{scope}-{name}.json")
        if action(agent, "read", "x") != "deny":
            raise SystemExit(f"{scope}/{name} nested target overlap did not deny concrete x")
        agent = load(f"permission-outer-inner-overlap-{scope}-{name}.json")
        if action(agent, "bash", "git status") != "deny":
            raise SystemExit(
                f"{scope}/{name} later nonmatching inner target erased Bash git-status deny"
            )

for family, permission, pattern in (
    ("nested-target-overlap", "read", "x"),
    ("outer-inner-overlap", "bash", "git status"),
):
    executor = load(f"permission-{family}-role-oh-no-executor.json")
    if action(executor, permission, pattern) != "deny":
        raise SystemExit(f"role executor {family} regression escaped deny")
    explore = load(f"permission-{family}-role-oh-no-explore.json")
    if action(explore, permission, pattern) == "deny":
        raise SystemExit(f"role-only {family} restriction leaked to explorer")

native_global = load("permission-native-global-output.json")
rank = {None: 0, "allow": 0, "ask": 1, "deny": 2}
for plugin_output, permission, pattern in (
    (load("permission-wildcard-overlap-global-oh-no.json"), "mcp-ab", "*"),
    (load("permission-nested-target-overlap-global-oh-no.json"), "read", "x"),
    (load("permission-outer-inner-overlap-global-oh-no.json"), "bash", "git status"),
):
    plugin_action = action(plugin_output, permission, pattern)
    native_action = action(native_global, permission, pattern)
    if rank[plugin_action] < rank[native_action]:
        raise SystemExit(
            f"plugin broadened native global host output for {permission} target {pattern}"
        )
PY
ok "real OpenCode preserves host inheritance, restrictive agent ceilings, and finite package policy"

log "Checking isolated OpenCode paths and real host discovery"
run_opencode_capture "$TEMP_ROOT/debug-paths.txt" debug paths
"$PYTHON_BIN" - "$TEMP_ROOT/debug-paths.txt" "$TEMP_ROOT" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
temp = sys.argv[2]
required = [
    f"{temp}/xdg-data",
    f"{temp}/xdg-config",
    f"{temp}/xdg-cache",
    f"{temp}/xdg-state",
]
missing = [value for value in required if value not in text]
if missing:
    raise SystemExit(f"OpenCode debug paths omitted isolated roots: {missing}\n{text}")
PY
ok "OpenCode reports only disposable XDG roots"

run_opencode_capture "$TEMP_ROOT/agent-list-before.txt" agent list
"$PYTHON_BIN" - "$TEMP_ROOT/agent-list-before.txt" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
expected = [
    "oh-no", "oh-no-explore", "oh-no-analyst", "oh-no-planner",
    "oh-no-plan-reviewer", "oh-no-executor", "oh-no-debugger",
    "oh-no-verifier", "oh-no-code-reviewer", "oh-no-fusion-rescue-analyst",
]
for name in expected:
    if re.search(rf"(?m)^\s*{re.escape(name)}\s+\((?:primary|subagent)\)\s*$", text) is None:
        raise SystemExit(f"real OpenCode agent list omitted {name!r}\n{text}")
if re.search(r"(?m)^\s*oh-no\s+\(primary\)\s*$", text) is None:
    raise SystemExit("oh-no was not discovered as a primary agent")
for name in expected[1:]:
    if re.search(rf"(?m)^\s*{re.escape(name)}\s+\(subagent\)\s*$", text) is None:
        raise SystemExit(f"{name} was not discovered as a subagent")
PY
ok "real OpenCode discovers oh-no primary and all nine named subagents"

# OpenCode 1.18.12 can truncate `debug skill` into invalid JSON when wrappers
# are large. Treat it as raw host evidence and bind that evidence to the exact
# generator/filesystem inventory asserted above instead of parsing it.
run_opencode_capture "$TEMP_ROOT/debug-skill.raw" debug skill
"$PYTHON_BIN" - "$TEMP_ROOT/debug-skill.raw" "$PLUGIN_ROOT_REAL" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
root = Path(sys.argv[2])
signals = [
    "auto-routing",
    str(root / "skills-opencode"),
    "SKILL.md",
    "oh-no-harness-generated-skill-wrapper",
]
missing = [signal for signal in signals if signal not in text]
if missing:
    raise SystemExit(f"raw OpenCode skill evidence omitted signals: {missing}")
PY
ok "raw OpenCode host evidence reaches the generated skills-opencode path"

log "Checking read-only status command and legacy apply non-writing"
CHECK_OUTPUT="$TEMP_ROOT/check-unconfigured.txt"
"$CONFIGURATOR" check >"$CHECK_OUTPUT"
[[ "$(<"$CHECK_OUTPUT")" == "STATUS: unconfigured" ]] \
  || fail "fresh isolated configurator state was not unconfigured"
[[ ! -e "$OH_NO_CONFIG_DIR/opencode-subagent-models.conf" ]] \
  || fail "check unexpectedly created preferences"
expect_status 2 "$TEMP_ROOT/check-extra.txt" "check with extra argument" \
  "$CONFIGURATOR" check unexpected
expect_status 2 "$TEMP_ROOT/legacy-apply.txt" "legacy apply" \
  "$CONFIGURATOR" apply explore=fixture/model
[[ ! -e "$OH_NO_CONFIG_DIR/opencode-subagent-models.conf" ]] \
  || fail "legacy CLI apply wrote preferences"
ok "status check is read-only and legacy CLI apply is rejected without writing"

ASSIGNMENTS=(
  "explore=fixture-provider/model-explore"
  "analyst=fixture-provider/model-analyst"
  "planner=fixture-provider/model/planner"
  "plan-reviewer=fixture-provider/model-plan-reviewer"
  "executor=fixture-provider/model-executor"
  "debugger=fixture-provider/model-debugger"
  "verifier=fixture-provider/model-verifier"
  "code-reviewer=fixture-provider/model-code-reviewer"
  "fusion-rescue-analyst=fixture-provider/model-fusion-rescue-analyst"
)
log "Publishing exact role models through the custom tool and checking a fresh process"
PLUGIN_URL="$PLUGIN_URL" "$NODE_BIN" --input-type=module >"$TEMP_ROOT/tool-valid.txt" <<'NODE'
const modelIDs = {
  explore: "model-explore",
  analyst: "model-analyst",
  planner: "model/planner",
  "plan-reviewer": "model-plan-reviewer",
  executor: "model-executor",
  debugger: "model-debugger",
  verifier: "model-verifier",
  "code-reviewer": "model-code-reviewer",
  "fusion-rescue-analyst": "model-fusion-rescue-analyst",
};
const models = Object.fromEntries(Object.entries(modelIDs).map(([role, id]) => [role, {
  id,
  name: role,
  variants: { high: {} },
}]));
const client = {
  config: {
    providers: async () => ({ data: { providers: [{ id: "fixture-provider", models }] } }),
    get: async () => ({ data: {} }),
  },
};
const hooks = await (await import(process.env.PLUGIN_URL)).default({ client, directory: process.cwd() });
const requests = [];
const result = await hooks.tool.oh_no_configure_subagents.execute({
  explore: "fixture-provider/model-explore",
  "explore-variant": "default",
  analyst: "fixture-provider/model-analyst",
  "analyst-variant": "high",
  planner: "fixture-provider/model/planner",
  "planner-variant": "high",
  "plan-reviewer": "fixture-provider/model-plan-reviewer",
  "plan-reviewer-variant": "high",
  executor: "fixture-provider/model-executor",
  "executor-variant": "high",
  debugger: "fixture-provider/model-debugger",
  "debugger-variant": "high",
  verifier: "fixture-provider/model-verifier",
  "verifier-variant": "high",
  "code-reviewer": "fixture-provider/model-code-reviewer",
  "code-reviewer-variant": "high",
  "fusion-rescue-analyst": "fixture-provider/model-fusion-rescue-analyst",
  "fusion-rescue-analyst-variant": "high",
}, { ask: async (request) => requests.push(request) });
if (requests.length !== 1 || requests[0].permission !== "oh_no_configure_subagents") {
  throw new Error("custom tool did not request host permission exactly once");
}
console.log(result);
NODE
"$PYTHON_BIN" - "$TEMP_ROOT/tool-valid.txt" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
if "STATUS: configured" not in text or "RESTART REQUIRED" not in text:
    raise SystemExit(f"successful custom tool call omitted status/restart output: {text!r}")
PY
"$CONFIGURATOR" check >"$TEMP_ROOT/check-configured.txt"
[[ "$(<"$TEMP_ROOT/check-configured.txt")" == "STATUS: configured" ]] \
  || fail "read-only status command did not report configured after tool publication"

PREFERENCES_FILE="$OH_NO_CONFIG_DIR/opencode-subagent-models.conf"
[[ -f "$PREFERENCES_FILE" && ! -L "$PREFERENCES_FILE" ]] \
  || fail "successful custom tool call did not create a regular preferences file"
"$NODE_BIN" --input-type=module - "$PREFERENCES_FILE" <<'NODE'
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const expected = `schema_version=2
assignment={"role":"explore","model":"fixture-provider/model-explore","variant":"default"}
assignment={"role":"analyst","model":"fixture-provider/model-analyst","variant":"high"}
assignment={"role":"planner","model":"fixture-provider/model/planner","variant":"high"}
assignment={"role":"plan-reviewer","model":"fixture-provider/model-plan-reviewer","variant":"high"}
assignment={"role":"executor","model":"fixture-provider/model-executor","variant":"high"}
assignment={"role":"debugger","model":"fixture-provider/model-debugger","variant":"high"}
assignment={"role":"verifier","model":"fixture-provider/model-verifier","variant":"high"}
assignment={"role":"code-reviewer","model":"fixture-provider/model-code-reviewer","variant":"high"}
assignment={"role":"fusion-rescue-analyst","model":"fixture-provider/model-fusion-rescue-analyst","variant":"high"}
`;
assert.equal(await readFile(process.argv[2], "utf8"), expected);
NODE

# This is a new Node process after custom tool publication, matching OpenCode's startup-only
# config hook lifecycle without requiring a provider credential or LLM call.
PLUGIN_URL="$PLUGIN_URL" "$NODE_BIN" --input-type=module <<'NODE'
import assert from "node:assert/strict";

const roles = [
  ["explore", "fixture-provider/model-explore"],
  ["analyst", "fixture-provider/model-analyst"],
  ["planner", "fixture-provider/model/planner"],
  ["plan-reviewer", "fixture-provider/model-plan-reviewer"],
  ["executor", "fixture-provider/model-executor"],
  ["debugger", "fixture-provider/model-debugger"],
  ["verifier", "fixture-provider/model-verifier"],
  ["code-reviewer", "fixture-provider/model-code-reviewer"],
  ["fusion-rescue-analyst", "fixture-provider/model-fusion-rescue-analyst"],
];
const hooks = await (await import(process.env.PLUGIN_URL)).default();
const config = {};
await hooks.config(config);
for (const [role, model] of roles) {
  assert.equal(config.agent[`oh-no-${role}`].model, model);
  if (role === "explore") {
    assert.equal(Object.hasOwn(config.agent[`oh-no-${role}`], "variant"), false);
  } else {
    assert.equal(config.agent[`oh-no-${role}`].variant, "high");
  }
}
NODE

# Separate real OpenCode processes prove the restarted host consumes each model
# assignment. Keep these calls serial and raw; no provider credential or model
# invocation is involved.
for assignment in "${ASSIGNMENTS[@]}"; do
  role="${assignment%%=*}"
  model="${assignment#*=}"
  output="$TEMP_ROOT/debug-agent-$role.txt"
  run_opencode_capture "$output" debug agent "oh-no-$role"
  "$PYTHON_BIN" - "$output" "$role" "$model" <<'PY'
import sys
import json
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
role, model = sys.argv[2:]
provider_id, model_id = model.split("/", 1)
try:
    agent = json.loads(text)
except json.JSONDecodeError as error:
    raise SystemExit(f"OpenCode debug agent returned invalid JSON for oh-no-{role}: {error}")
if agent.get("model") != {"providerID": provider_id, "modelID": model_id}:
    raise SystemExit(
        f"restarted OpenCode debug agent returned the wrong oh-no-{role} model: "
        f"{agent.get('model')!r}"
    )
PY
done
ok "fresh direct and real OpenCode processes consume all nine exact provider/model IDs"

log "Rechecking that legacy CLI apply cannot mutate configured preferences"
PREFERENCES_BEFORE="$($NODE_BIN -e 'process.stdout.write(require("node:fs").readFileSync(process.argv[1]).toString("base64"))' "$PREFERENCES_FILE")"
expect_status 2 "$TEMP_ROOT/legacy-apply-existing.txt" "legacy apply over existing preferences" \
  "$CONFIGURATOR" apply "${ASSIGNMENTS[@]}"
[[ "$PREFERENCES_BEFORE" == "$($NODE_BIN -e 'process.stdout.write(require("node:fs").readFileSync(process.argv[1]).toString("base64"))' "$PREFERENCES_FILE")" ]] \
  || fail "legacy CLI apply changed previous preference bytes"
ok "legacy CLI apply remains non-writing after configuration"

log "Checking temporary project immutability"
PROJECT_MANIFEST_AFTER="$(project_manifest)"
PROJECT_STATUS_AFTER="$(git -C "$PROJECT_ROOT" status --porcelain=v1 --untracked-files=all)"
[[ "$PROJECT_MANIFEST_AFTER" == "$PROJECT_MANIFEST_BEFORE" ]] \
  || fail "OpenCode/plugin/configurator mutated the temporary project filesystem"
[[ "$PROJECT_STATUS_AFTER" == "$PROJECT_STATUS_BEFORE" ]] \
  || fail "OpenCode/plugin/configurator changed temporary project git status"
ok "temporary git project remained byte-for-byte unchanged outside .git"

printf '\nPASS: isolated deterministic OpenCode plugin driver (opencode %s)\n' "$OPENCODE_VERSION" >&2
