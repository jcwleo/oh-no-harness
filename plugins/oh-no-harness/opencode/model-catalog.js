import { DEFAULT_VARIANT, normalizeModelAssignments, ROLES } from "./preferences.js";

export const MODEL_CATALOG_TOOL = "oh_no_get_model_catalog";
export const MODEL_CATALOG_PAGE_SIZE = 40;

function responseData(response) {
  if (response?.error) throw new Error("OpenCode provider catalog request failed");
  return response?.data ?? response;
}

function modelVariants(model) {
  const variants = Object.entries(model?.variants ?? {})
    .filter(([name, value]) => name.length > 0 && value?.disabled !== true)
    .map(([name]) => name);
  return [DEFAULT_VARIANT, ...variants.filter((name) => name !== DEFAULT_VARIANT)];
}

export function normalizeProviderCatalog(value) {
  const providers = value?.providers;
  if (!Array.isArray(providers)) return null;

  const models = [];
  for (const provider of providers) {
    if (!provider || typeof provider.id !== "string" || provider.id.length === 0) continue;
    for (const [key, model] of Object.entries(provider.models ?? {})) {
      const modelID = typeof model?.id === "string" ? model.id : key;
      if (!modelID) continue;
      models.push({
        id: `${provider.id}/${modelID}`,
        name: typeof model.name === "string" ? model.name : modelID,
        provider: provider.id,
        status: typeof model.status === "string" ? model.status : "active",
        variants: modelVariants(model),
      });
    }
  }
  models.sort((first, second) => first.id.localeCompare(second.id));
  return models.length > 0 ? models : null;
}

export async function fetchModelCatalog(client, directory) {
  if (typeof client?.config?.providers !== "function") {
    return { status: "catalog-unavailable", models: [] };
  }
  try {
    const [response, configResponse] = await Promise.all([
      client.config.providers({ query: { directory } }),
      typeof client.config.get === "function"
        ? client.config.get({ query: { directory } }).catch(() => null)
        : null,
    ]);
    const models = normalizeProviderCatalog(responseData(response));
    const config = configResponse ? responseData(configResponse) : null;
    const configuredPrimary = config?.agent?.["oh-no"]?.model ?? config?.model;
    const primaryModel = models?.some((model) => model.id === configuredPrimary)
      ? configuredPrimary
      : null;
    return models
      ? { status: "available", primary_model: primaryModel, models }
      : { status: "catalog-unavailable", primary_model: null, models: [] };
  } catch {
    return { status: "catalog-unavailable", primary_model: null, models: [] };
  }
}

export function validateCatalogAssignments(value, catalog) {
  const assignments = normalizeModelAssignments(value);
  if (!assignments || catalog?.status !== "available") return null;
  const available = new Map(catalog.models.map((model) => [model.id, new Set(model.variants)]));
  for (const role of ROLES) {
    const assignment = assignments.get(role);
    if (!available.get(assignment.model)?.has(assignment.variant)) return null;
  }
  return assignments;
}

export function formatModelCatalog(
  catalog,
  preferenceState,
  query = { mode: "providers", provider: "", cursor: "0" },
) {
  const current = {};
  if (preferenceState?.status === "configured") {
    for (const role of ROLES) current[role] = preferenceState.assignments.get(role);
  }
  if (catalog.status !== "available") {
    return JSON.stringify({ status: catalog.status });
  }

  const byID = new Map(catalog.models.map((model) => [model.id, model]));
  if (query.mode === "providers") {
    if (query.provider !== "" || query.cursor !== "0") {
      return JSON.stringify({ status: "invalid-query" });
    }
    const providerCounts = new Map();
    for (const model of catalog.models) {
      providerCounts.set(model.provider, (providerCounts.get(model.provider) ?? 0) + 1);
    }
    const featuredIDs = new Set([
      catalog.primary_model,
      ...Object.values(current).map((assignment) => assignment.model),
    ]);
    return JSON.stringify({
      status: "available",
      primary_model: catalog.primary_model ?? null,
      providers: [...providerCounts].map(([id, model_count]) => ({ id, model_count })),
      featured_models: [...featuredIDs].filter((id) => byID.has(id)).map((id) => byID.get(id)),
      current_assignments: Object.fromEntries(
        Object.entries(current).map(([role, assignment]) => [role, {
          ...assignment,
          available: byID.get(assignment.model)?.variants.includes(assignment.variant) ?? false,
        }]),
      ),
    });
  }

  if (query.mode !== "models") return JSON.stringify({ status: "invalid-query" });

  const providerModels = catalog.models.filter((model) => model.provider === query.provider);
  const cursor = Number.parseInt(query.cursor, 10);
  if (
    providerModels.length === 0 ||
    !Number.isSafeInteger(cursor) ||
    cursor < 0 ||
    cursor >= providerModels.length
  ) {
    return JSON.stringify({ status: "invalid-query" });
  }
  const models = providerModels.slice(cursor, cursor + MODEL_CATALOG_PAGE_SIZE);
  const next = cursor + models.length;
  return JSON.stringify({
    status: "available",
    provider: query.provider,
    cursor: String(cursor),
    models,
    next_cursor: next < providerModels.length ? String(next) : null,
  });
}
