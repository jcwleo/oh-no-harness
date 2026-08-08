#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_ROOT="${OH_NO_PLUGIN_ROOT:-$REPO_ROOT/plugins/oh-no-harness}"
NPM_BIN="${NPM_BIN:-npm}"
NODE_BIN="${NODE_BIN:-node}"

TEMP_ROOT=""

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

command -v "$NPM_BIN" >/dev/null 2>&1 || fail "required command not found: $NPM_BIN"
command -v "$NODE_BIN" >/dev/null 2>&1 || fail "required command not found: $NODE_BIN"
[[ -f "$PLUGIN_ROOT/package.json" ]] || fail "missing npm package metadata"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-opencode-package.XXXXXX")"
PACK_DIR="$TEMP_ROOT/pack"
INSTALL_DIR="$TEMP_ROOT/install"
mkdir -p "$PACK_DIR" "$INSTALL_DIR"

# By default this test packs the plugin root itself. The release helper instead
# supplies OH_NO_PACKAGE_TARBALL so the artifact tested here is byte-identical
# to the one it later publishes.
SUPPLIED_TARBALL="${OH_NO_PACKAGE_TARBALL:-}"
if [[ -n "$SUPPLIED_TARBALL" ]]; then
  [[ -f "$SUPPLIED_TARBALL" ]] || fail "supplied tarball not found: $SUPPLIED_TARBALL"
  SUPPLIED_TARBALL="$(cd -- "$(dirname -- "$SUPPLIED_TARBALL")" && pwd)/$(basename -- "$SUPPLIED_TARBALL")"
  "$NPM_BIN" pack "$SUPPLIED_TARBALL" --dry-run --json --pack-destination "$PACK_DIR" \
    >"$TEMP_ROOT/pack.json"
else
  "$NPM_BIN" pack "$PLUGIN_ROOT" --json --pack-destination "$PACK_DIR" \
    >"$TEMP_ROOT/pack.json"
fi

TARBALL="$($NODE_BIN --input-type=module - "$TEMP_ROOT/pack.json" "$PACK_DIR" "$PLUGIN_ROOT/package.json" "$SUPPLIED_TARBALL" <<'NODE'
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const [reportPath, packDirectory, packagePath, suppliedTarball] = process.argv.slice(2);
const report = JSON.parse(readFileSync(reportPath, "utf8"));
const packageMetadata = JSON.parse(readFileSync(packagePath, "utf8"));
if (!Array.isArray(report) || report.length !== 1) {
  throw new Error("npm pack did not return exactly one package report");
}
const entry = report[0];
if (entry.id !== `${packageMetadata.name}@${packageMetadata.version}`) {
  throw new Error(`unexpected package identity: ${entry.id}`);
}
const names = new Set(entry.files.map((file) => file.path));
for (const required of [
  "package.json",
  "opencode/index.js",
  "opencode/setup.js",
  "opencode/model-catalog.js",
  "opencode/preferences.js",
  "opencode/preference-writer.js",
  "opencode/configure-opencode-subagents",
  "opencode/generated/agents.json",
  "opencode/generated/commands.json",
  "skills-opencode/interview/SKILL.md",
  "skills-opencode/configure-subagents/SKILL.md",
]) {
  if (!names.has(required)) throw new Error(`packed artifact is missing ${required}`);
}
for (const forbidden of ["agents/", "commands/", "hooks/", "skills-claude/", "skills/"]) {
  if ([...names].some((name) => name.startsWith(forbidden))) {
    throw new Error(`packed artifact contains non-OpenCode surface ${forbidden}`);
  }
}
process.stdout.write(suppliedTarball || resolve(packDirectory, entry.filename));
NODE
)"

"$NPM_BIN" install --ignore-scripts --no-audit --no-fund --prefix "$INSTALL_DIR" \
  "$TARBALL" >/dev/null

INSTALLED_ROOT="$INSTALL_DIR/node_modules/oh-no-harness"
[[ -f "$INSTALLED_ROOT/opencode/index.js" ]] || fail "installed package entrypoint is missing"
[[ -x "$INSTALL_DIR/node_modules/.bin/oh-no-harness" ]] \
  || fail "installed package setup bin is missing or non-executable"

"$NODE_BIN" --input-type=module - "$INSTALL_DIR" <<'NODE'
import { createRequire } from "node:module";
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const installDirectory = process.argv[2];
const require = createRequire(pathToFileURL(`${installDirectory}/package-probe.mjs`));
const entrypoint = require.resolve("oh-no-harness");
const module = await import(pathToFileURL(entrypoint));
if (typeof module.default !== "function") {
  throw new Error("package default export is not an OpenCode plugin function");
}
const metadata = JSON.parse(
  await readFile(`${installDirectory}/node_modules/oh-no-harness/package.json`, "utf8"),
);
if (metadata.bin?.["oh-no-harness"] !== "./opencode/setup.js") {
  throw new Error("package bin does not expose the setup CLI");
}
NODE

"$NODE_BIN" "$REPO_ROOT/scripts/test-opencode-setup.mjs" \
  "$INSTALL_DIR/node_modules/.bin/oh-no-harness"

set +e
OPENCODE_CONFIG_DIR="$TEMP_ROOT/npm-exec-config" \
  "$NPM_BIN" exec --yes --package "$TARBALL" -- oh-no-harness setup --check \
  >"$TEMP_ROOT/npm-exec-check.txt" 2>&1
NPM_EXEC_STATUS=$?
set -e
[[ "$NPM_EXEC_STATUS" == 1 ]] || fail "npm exec setup --check returned $NPM_EXEC_STATUS"
"$NODE_BIN" -e '
  const text = require("node:fs").readFileSync(process.argv[1], "utf8");
  if (!/^STATUS: unconfigured$/mu.test(text)) process.exit(1);
' "$TEMP_ROOT/npm-exec-check.txt" || fail "npm exec did not invoke the setup binary"
[[ ! -e "$TEMP_ROOT/npm-exec-config" ]] \
  || fail "read-only npm exec setup --check created the config directory"

OH_NO_PLUGIN_ROOT="$INSTALLED_ROOT" "$REPO_ROOT/scripts/test-opencode-plugin.sh"
printf '\nPASS: packed npm artifact installs and loads through OpenCode\n'
