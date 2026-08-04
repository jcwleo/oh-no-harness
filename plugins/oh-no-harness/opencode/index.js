import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  formatPreferenceWriteResult,
  writePreferenceAssignments,
} from "./preference-writer.js";
import {
  fetchModelCatalog,
  formatModelCatalog,
  MODEL_CATALOG_TOOL,
  validateCatalogAssignments,
} from "./model-catalog.js";
import {
  DEFAULT_VARIANT,
  MODEL_SCHEMA_PATTERN,
  readPreferenceState,
  ROLES,
  VARIANT_SCHEMA_PATTERN,
} from "./preferences.js";

const AGENTS_URL = new URL("./generated/agents.json", import.meta.url);
const COMMANDS_URL = new URL("./generated/commands.json", import.meta.url);
const SKILLS_PATH = path.normalize(
  fileURLToPath(new URL("../skills-opencode", import.meta.url)),
);
const ACTIONS = new Set(["allow", "ask", "deny"]);
const ACTION_RANK = { allow: 0, ask: 1, deny: 2 };
const CONFIGURE_TOOL = "oh_no_configure_subagents";
const MODEL_CATALOG_TOOL_ARGS = Object.freeze({
  mode: {
    type: "string",
    enum: ["providers", "models"],
    description: "Use providers for the initial index, or models to browse one provider.",
  },
  provider: {
    type: "string",
    description: "Use an empty string for providers mode, or one exact returned provider ID.",
  },
  cursor: {
    type: "string",
    pattern: "^(0|[1-9][0-9]*)$",
    description: "Use 0 for providers mode or a first model page, then an exact next_cursor.",
  },
});
const CONFIGURE_TOOL_ARGS = Object.freeze(Object.fromEntries(ROLES.flatMap((role) => [
  [
    role,
    {
      type: "string",
      pattern: MODEL_SCHEMA_PATTERN,
      description: `Exact available provider/model-id for the ${role} role.`,
    },
  ],
  [
    `${role}-variant`,
    {
      type: "string",
      pattern: VARIANT_SCHEMA_PATTERN,
      description: `Exact available OpenCode variant for the ${role} role, or default.`,
    },
  ],
])));

function wildcardMatch(value, pattern) {
  const escaped = pattern
    .replaceAll("\\", "/")
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");
  const optionalTrailing = escaped.endsWith(" .*")
    ? `${escaped.slice(0, -3)}( .*)?`
    : escaped;
  const flags = process.platform === "win32" ? "si" : "s";
  return new RegExp(`^${optionalTrailing}$`, flags).test(value.replaceAll("\\", "/"));
}

function policyAction(policy, target) {
  if (ACTIONS.has(policy)) return policy;
  if (!policy || Array.isArray(policy) || typeof policy !== "object") {
    return undefined;
  }

  if (target === undefined) {
    return Object.values(policy).reduce(
      (action, candidate) =>
        candidate === "ask" || candidate === "deny"
          ? stricterAction(action, candidate)
          : action,
      undefined,
    );
  }

  let action;
  for (const [pattern, candidate] of Object.entries(policy)) {
    if (ACTIONS.has(candidate) && wildcardMatch(target, pattern)) action = candidate;
  }
  return action;
}

function concretePermissionAction(permission, tool, target) {
  if (tool.includes("*") || tool.includes("?")) {
    throw new TypeError("Permission evaluation requires a concrete tool name");
  }
  if (ACTIONS.has(permission)) return permission;
  if (!permission || Array.isArray(permission) || typeof permission !== "object") {
    return undefined;
  }

  let action;
  for (const [toolPattern, policy] of Object.entries(permission)) {
    if (!wildcardMatch(tool, toolPattern)) continue;
    const candidate = policyAction(policy, target);
    // Flattened OpenCode rules retain an earlier matching outer rule when a
    // later outer rule has no matching inner target.
    if (candidate !== undefined) action = candidate;
  }
  return action;
}

function stricterAction(first, second) {
  if (first === undefined) return second;
  if (second === undefined) return first;
  return ACTION_RANK[first] >= ACTION_RANK[second] ? first : second;
}

function finitePackageAction(packageAction, permissions, tool, target) {
  return permissions.reduce(
    (action, permission) =>
      stricterAction(action, concretePermissionAction(permission, tool, target)),
    packageAction,
  );
}

function addRestriction(groups, toolPattern, targetPattern, action) {
  if (action !== "ask" && action !== "deny") return;
  let targets = groups.get(toolPattern);
  if (!targets) {
    targets = new Map();
    groups.set(toolPattern, targets);
  }
  targets.set(targetPattern, stricterAction(targets.get(targetPattern), action));
}

function collectRestrictions(groups, permission) {
  if (permission === "ask" || permission === "deny") {
    addRestriction(groups, "*", "*", permission);
    return;
  }
  if (!permission || Array.isArray(permission) || typeof permission !== "object") {
    return;
  }

  for (const [toolPattern, policy] of Object.entries(permission)) {
    if (ACTIONS.has(policy)) {
      addRestriction(groups, toolPattern, "*", policy);
      continue;
    }
    if (!policy || Array.isArray(policy) || typeof policy !== "object") continue;
    for (const [targetPattern, action] of Object.entries(policy)) {
      addRestriction(groups, toolPattern, targetPattern, action);
    }
  }
}

function restrictivePermission(permissions) {
  const groups = new Map();
  for (const permission of permissions) collectRestrictions(groups, permission);

  const entries = [...groups.entries()];
  const mixed = entries.filter(([, targets]) => {
    const actions = new Set(targets.values());
    return actions.has("ask") && actions.has("deny");
  });
  // Distinct mixed outer patterns can overlap in ways that cannot be represented
  // safely by one ordered object. Denying their ask portions is conservative and
  // avoids attempting symbolic glob containment or overlap algebra.
  if (mixed.length > 1) {
    for (const [, targets] of mixed) {
      for (const [pattern, action] of targets) {
        if (action === "ask") targets.set(pattern, "deny");
      }
    }
  }

  const groupRank = (targets) => {
    const actions = new Set(targets.values());
    if (!actions.has("deny")) return 0;
    return actions.has("ask") ? 1 : 2;
  };
  entries.sort((first, second) => groupRank(first[1]) - groupRank(second[1]));

  const result = {};
  for (const [toolPattern, targets] of entries) {
    const ordered = [...targets].sort(
      (first, second) => ACTION_RANK[first[1]] - ACTION_RANK[second[1]],
    );
    result[toolPattern] = ordered.length === 1 && ordered[0][0] === "*"
      ? ordered[0][1]
      : Object.fromEntries(ordered);
  }
  return result;
}

function applyExactRestriction(permission, tool, action) {
  const existing = permission[tool];
  if (!existing || ACTIONS.has(existing)) {
    permission[tool] = stricterAction(existing, action);
    return;
  }
  if (action === "deny") permission[tool] = { ...existing, "*": "deny" };
}

function applyPackagePermissions(packageAgents, globalPermission, existingAgents) {
  const roleKeys = ROLES.map((role) => `oh-no-${role}`);
  const primaryPermission = existingAgents["oh-no"]?.permission;
  for (const [name, agent] of Object.entries(packageAgents)) {
    const packagePermission = agent.permission ?? {};
    const rolePermission = existingAgents[name]?.permission;
    // Agent-local rules are evaluated after global rules by OpenCode. Mirror
    // only the restrictive global portions here so a primary/role `ask` can
    // never weaken a global `deny` through last-match ordering.
    const agentCeilings = name === "oh-no"
      ? [globalPermission, primaryPermission]
      : [globalPermission, primaryPermission, rolePermission];
    const finiteCeilings = name === "oh-no"
      ? [globalPermission, primaryPermission]
      : [globalPermission, primaryPermission, rolePermission];
    const permission = restrictivePermission([...agentCeilings, packagePermission]);

    if (name === "oh-no") {
      permission.question = finitePackageAction(
        packagePermission.question,
        finiteCeilings,
        "question",
      );
    }

    if (packagePermission.task !== undefined) {
      const allowedTargets = roleKeys.filter(
        (target) =>
          concretePermissionAction(packagePermission, "task", target) === "allow",
      );
      const task = ACTIONS.has(permission.task)
        ? { "*": permission.task }
        : { ...(permission.task ?? {}), "*": "deny" };
      for (const target of allowedTargets) {
        const action = finitePackageAction(
          "allow",
          finiteCeilings,
          "task",
          target,
        );
        if (action !== "deny") task[target] = action;
      }
      permission.task = Object.keys(task).length === 1 ? "deny" : task;
    }

    for (const tool of [MODEL_CATALOG_TOOL, CONFIGURE_TOOL]) {
      applyExactRestriction(
        permission,
        tool,
        finitePackageAction(packagePermission[tool], finiteCeilings, tool),
      );
    }
    packageAgents[name] = { ...agent, permission };
  }
}

async function readGeneratedObject(url) {
  const value = JSON.parse(await readFile(url, "utf8"));
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new TypeError(`Expected an object in ${fileURLToPath(url)}`);
  }
  return value;
}

export default async function ohNoHarness({ client, directory } = {}) {
  const [generatedAgents, generatedCommands] = await Promise.all([
    readGeneratedObject(AGENTS_URL),
    readGeneratedObject(COMMANDS_URL),
  ]);

  return {
    tool: {
      [MODEL_CATALOG_TOOL]: {
        description:
          "List the exact models and model-specific variants currently available to OpenCode for an explicit subagent configuration request.",
        args: MODEL_CATALOG_TOOL_ARGS,
        execute: async (args) => {
          const [catalog, preferenceState] = await Promise.all([
            fetchModelCatalog(client, directory),
            readPreferenceState().catch(() => ({ status: "invalid-preferences" })),
          ]);
          return formatModelCatalog(catalog, preferenceState, args);
        },
      },
      [CONFIGURE_TOOL]: {
        description:
          "Publish all nine exact Oh No Harness OpenCode subagent model and variant assignments after explicit user confirmation.",
        args: CONFIGURE_TOOL_ARGS,
        execute: async (args, context) => {
          const requested = Object.fromEntries(
            ROLES.map((role) => [
              role,
              { model: args[role], variant: args[`${role}-variant`] },
            ]),
          );
          const catalog = await fetchModelCatalog(client, directory);
          if (catalog.status !== "available") {
            return "STATUS: catalog-unavailable\nPreferences were not changed.";
          }
          const assignments = validateCatalogAssignments(requested, catalog);
          if (!assignments) {
            return "STATUS: invalid-assignments\nPreferences were not changed.";
          }
          await context.ask({
            permission: CONFIGURE_TOOL,
            patterns: ["*"],
            always: [],
            metadata: { operation: "configure-subagents", role_count: ROLES.length },
          });
          return formatPreferenceWriteResult(await writePreferenceAssignments(assignments));
        },
      },
    },
    config: async (config) => {
      const preferenceState = await readPreferenceState().catch(() => ({
        status: "invalid-preferences",
      }));
      const roleKeys = ROLES.map((role) => `oh-no-${role}`);
      const canSetModels =
        preferenceState.status === "configured" &&
        roleKeys.every((key) => Object.hasOwn(generatedAgents, key));

      const packageAgents = { ...generatedAgents };
      const existingAgents = config.agent ?? {};
      applyPackagePermissions(packageAgents, config.permission, existingAgents);
      if (canSetModels) {
        for (let index = 0; index < ROLES.length; index += 1) {
          const key = roleKeys[index];
          const assignment = preferenceState.assignments.get(ROLES[index]);
          packageAgents[key] = {
            ...packageAgents[key],
            model: assignment.model,
            ...(assignment.variant === DEFAULT_VARIANT
              ? {}
              : { variant: assignment.variant }),
          };
        }
      }

      config.agent = {
        ...existingAgents,
        ...packageAgents,
        build: { ...existingAgents.build, disable: true },
        plan: { ...existingAgents.plan, disable: true },
      };
      config.command = { ...(config.command ?? {}), ...generatedCommands };

      const skills = config.skills ?? {};
      const paths = Array.isArray(skills.paths) ? [...skills.paths] : [];
      const alreadyRegistered = paths.some(
        (entry) =>
          typeof entry === "string" &&
          path.isAbsolute(entry) &&
          path.resolve(entry) === SKILLS_PATH,
      );
      if (!alreadyRegistered) paths.push(SKILLS_PATH);
      config.skills = { ...skills, paths };

      if (
        config.default_agent === undefined ||
        config.default_agent === "build" ||
        config.default_agent === "plan"
      ) {
        config.default_agent = "oh-no";
      }
      if (!Number.isInteger(config.subagent_depth) || config.subagent_depth < 2) {
        config.subagent_depth = 2;
      }
    },
  };
}
