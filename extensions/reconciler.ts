import { readFileSync, writeFileSync, renameSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { baseModelId, REASONING_OVERRIDES } from "./discovery.js";
import type { ModelStore, StoredCapabilities, SaiaModelResponse } from "./types.js";

export interface ReconcilerConfig {
  startupDelayMs: number;
  intervalMs: number;
  staleAfterMs: number;
  probesPerCycle: number;
  probeTimeoutMs: number;
  reverifyMs: number;
  scrapeIntervalMs: number;
  scrapeTimeoutMs: number;
  storePath: string;
  disabled: boolean;
}

export const DEFAULT_CONFIG: ReconcilerConfig = {
  startupDelayMs: 5_000,
  intervalMs: 21_600_000,
  staleAfterMs: 43_200_000,
  probesPerCycle: 2,
  probeTimeoutMs: 20_000,
  reverifyMs: 604_800_000,
  scrapeIntervalMs: 604_800_000,
  scrapeTimeoutMs: 15_000,
  storePath: join(homedir(), ".omp", "agent", "saia-models.json"),
  disabled: false,
};

function positiveInt(raw: string | undefined, fallback: number): number {
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

function disabledFlag(raw: string | undefined): boolean {
  if (raw === undefined || raw === "") return false;
  const v = raw.trim().toLowerCase();
  return v !== "0" && v !== "false" && v !== "no";
}

export function parseProbeStream(chunks: string[]): boolean | null {
  let sawReasoning = false;
  let sawContent = false;
  for (const line of chunks) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("data:")) continue;
    const payload = trimmed.slice(5).trim();
    if (payload === "[DONE]") continue;
    let parsed: {
      error?: unknown;
      choices?: Array<{ delta?: Record<string, unknown> }>;
    };
    try {
      parsed = JSON.parse(payload);
    } catch {
      continue;
    }
    if (parsed.error) return null;
    const delta = parsed.choices?.[0]?.delta;
    if (!delta) continue;
    if (delta.reasoning != null) sawReasoning = true;
    if (delta.reasoning_content != null) sawReasoning = true;
    if (delta.reasoning_text != null) sawReasoning = true;
    if (delta.content != null && delta.content !== "") sawContent = true;
  }
  if (sawReasoning) return true;
  if (sawContent) return false;
  return null;
}

export async function probeReasoning(
  fetchImpl: typeof fetch,
  baseUrl: string,
  apiKey: string,
  modelId: string,
  timeoutMs: number,
): Promise<boolean | null> {
  const res = await fetchImpl(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: modelId,
      messages: [{ role: "user", content: "Say OK" }],
      reasoning_effort: "high",
      max_tokens: 1,
      stream: true,
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) return null;
  const text = await res.text();
  return parseProbeStream(text.split("\n"));
}

export const SCRAPE_URL =
  "https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html";

export function normalizeModelName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function stripTags(s: string): string {
  return s.replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").trim();
}

/** Parse a docs-page context cell: "1M" -> 1_000_000, "262K" -> 262_000, "4096" -> 4096. */
function parseContext(raw: string): number | undefined {
  const m = raw.replace(/,/g, "").match(/^([\d.]+)\s*([kKmM])?$/);
  if (!m) return undefined;
  const n = Number(m[1]);
  if (!Number.isFinite(n) || n <= 0) return undefined;
  const suffix = m[2]?.toLowerCase();
  const mult = suffix === "k" ? 1_000 : suffix === "m" ? 1_000_000 : 1;
  return Math.round(n * mult);
}

/**
 * Parse the SAIA docs page into normalized-name -> context window.
 * The page's model table (row cells: flag, display name, ..., context, ...) does
 * not carry API model ids, so keys are normalized display names; the API's own
 * `name` field matches the display names (verified 2026-08-19 against the live
 * page and /v1/models for all 16 served models).
 */
export function parseScrape(html: string): Record<string, number> {
  const result: Record<string, number> = {};
  const rows = html.match(/<tr[^>]*>[\s\S]*?<\/tr>/g) ?? [];
  for (const row of rows) {
    const cells = row.match(/<td[^>]*>([\s\S]*?)<\/td>/g) ?? [];
    if (cells.length < 5) continue;
    const name = stripTags(cells[1]);
    const ctx = parseContext(stripTags(cells[4]));
    if (name && ctx !== undefined) result[normalizeModelName(name)] = ctx;
  }
  return result;
}

/** Match a model name against scraped normalized-name keys (exact, then containment). */
export function matchScrapedContext(
  scraped: Record<string, number>,
  modelName: string,
): number | undefined {
  const key = normalizeModelName(modelName);
  if (scraped[key] !== undefined) return scraped[key];
  for (const [k, v] of Object.entries(scraped)) {
    if (k.includes(key) || key.includes(k)) return v;
  }
  return undefined;
}

export async function scrapeContextWindows(
  fetchImpl: typeof fetch,
  url: string,
  timeoutMs: number,
): Promise<Record<string, number> | null> {
  const res = await fetchImpl(url, { signal: AbortSignal.timeout(timeoutMs) });
  if (!res.ok) return null;
  return parseScrape(await res.text());
}

/**
 * Choose which models to probe this cycle, bounded by probesPerCycle.
 * Authoritative signals (API "thought" or override-set membership) never probe.
 * Backoff: a recent probe (success OR failure) defers the next probe until
 * reverifyMs elapses — applyProbeResult sets probedAt on failure too, so a
 * failing model is not re-probed every cycle.
 */
export function planProbes(
  store: ModelStore,
  list: SaiaModelResponse["data"],
  config: ReconcilerConfig,
  now: Date,
): string[] {
  const probes: string[] = [];
  for (const entry of list) {
    if (probes.length >= config.probesPerCycle) break;
    if (entry.output?.includes("thought")) continue;
    if (REASONING_OVERRIDES[entry.id] === true) continue;
    if (REASONING_OVERRIDES[baseModelId(entry.id)] === true) continue;
    const probedAt = store.models[entry.id]?.probedAt
      ? new Date(store.models[entry.id].probedAt!).getTime()
      : 0;
    const due = probedAt === 0 || probedAt + config.reverifyMs <= now.getTime();
    if (due) probes.push(entry.id);
  }
  return probes;
}

export function applyProbeResult(
  store: ModelStore,
  id: string,
  reasoning: boolean | null,
  now: Date,
): ModelStore {
  const entry: StoredCapabilities = { ...(store.models[id] ?? {}) };
  if (reasoning === null) {
    entry.probedAt = now.toISOString();
    entry.probeFailures = (entry.probeFailures ?? 0) + 1;
  } else {
    entry.reasoning = reasoning;
    entry.probedAt = now.toISOString();
    entry.probeFailures = 0;
  }
  return { ...store, models: { ...store.models, [id]: entry } };
}

/**
 * Refresh per-model fields from authoritative API data plus fresh scrape
 * results. Scrape keys are normalized display names; each API entry's `name`
 * is matched against them (scrape wins over the store per design decision).
 */
export function reconcileFields(
  store: ModelStore,
  list: SaiaModelResponse["data"],
  scrapedContext: Record<string, number> | null,
  now: Date,
): ModelStore {
  const models: ModelStore["models"] = { ...store.models };
  for (const entry of list) {
    const existing: StoredCapabilities = { ...(models[entry.id] ?? {}) };
    if (entry.input?.includes("image")) existing.vision = true;
    else if (entry.input?.length) existing.vision = false;
    if (entry.output?.includes("thought")) existing.reasoning = true;
    else if (REASONING_OVERRIDES[entry.id] === true) existing.reasoning = true;
    else if (REASONING_OVERRIDES[baseModelId(entry.id)] === true) existing.reasoning = true;
    if (scrapedContext) {
      const ctx = matchScrapedContext(scrapedContext, entry.name);
      if (ctx !== undefined) existing.contextWindow = ctx;
    }
    models[entry.id] = existing;
  }
  return { version: 1, updatedAt: now.toISOString(), contextScrapedAt: store.contextScrapedAt, models };
}

export function parseConfig(env: Record<string, string | undefined>): ReconcilerConfig {
  return {
    startupDelayMs: positiveInt(env.SAIA_RECONCILE_STARTUP_DELAY_MS, DEFAULT_CONFIG.startupDelayMs),
    intervalMs: positiveInt(env.SAIA_RECONCILE_INTERVAL_MS, DEFAULT_CONFIG.intervalMs),
    staleAfterMs: positiveInt(env.SAIA_RECONCILE_STALE_AFTER_MS, DEFAULT_CONFIG.staleAfterMs),
    probesPerCycle: positiveInt(env.SAIA_RECONCILE_PROBES_PER_CYCLE, DEFAULT_CONFIG.probesPerCycle),
    probeTimeoutMs: positiveInt(env.SAIA_RECONCILE_PROBE_TIMEOUT_MS, DEFAULT_CONFIG.probeTimeoutMs),
    reverifyMs: positiveInt(env.SAIA_RECONCILE_REVERIFY_MS, DEFAULT_CONFIG.reverifyMs),
    scrapeIntervalMs: positiveInt(env.SAIA_RECONCILE_SCRAPE_INTERVAL_MS, DEFAULT_CONFIG.scrapeIntervalMs),
    scrapeTimeoutMs: positiveInt(env.SAIA_RECONCILE_SCRAPE_TIMEOUT_MS, DEFAULT_CONFIG.scrapeTimeoutMs),
    storePath: env.SAIA_RECONCILE_STORE_PATH?.trim() || DEFAULT_CONFIG.storePath,
    disabled: disabledFlag(env.SAIA_RECONCILE_DISABLED),
  };
}

const EMPTY_UPDATED_AT = new Date(0).toISOString();

export function loadStore(path: string): ModelStore {
  if (!existsSync(path)) {
    return { version: 1, updatedAt: EMPTY_UPDATED_AT, models: {} };
  }
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as Partial<ModelStore>;
    if (
      parsed?.version !== 1 ||
      typeof parsed.models !== "object" ||
      parsed.models === null
    ) {
      throw new Error("unexpected store shape");
    }
    return {
      version: 1,
      updatedAt: typeof parsed.updatedAt === "string" ? parsed.updatedAt : EMPTY_UPDATED_AT,
      contextScrapedAt:
        typeof parsed.contextScrapedAt === "string" ? parsed.contextScrapedAt : undefined,
      models: parsed.models as ModelStore["models"],
    };
  } catch {
    try {
      renameSync(path, `${path}.corrupt-${Date.now()}`);
    } catch {
      // quarantine is best-effort
    }
    return { version: 1, updatedAt: EMPTY_UPDATED_AT, models: {} };
  }
}

export function saveStore(path: string, store: ModelStore): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.tmp`;
  writeFileSync(tmp, JSON.stringify(store, null, 2));
  renameSync(tmp, path);
}
