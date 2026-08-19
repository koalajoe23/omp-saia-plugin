# SAIA Model Capability Reconciliation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically keep SAIA model capabilities (list, reasoning, vision, context window) reconciled in the background and at startup, invisibly to the user, with a manual `/saia-refresh` trigger.

**Architecture:** A new `reconciler.ts` owns a persisted JSON store (`~/.omp/agent/saia-models.json` by default). A detached cycle (deferred startup + managed timer, single-flight) refreshes it: model list from `/v1/models`, vision from API modalities, reasoning via tiny probes for unknown/due models, context windows via docs-page scrape with static-table fallback. `fetchDynamicModels` merges the store over the existing static tables so omp always sees the best known state. All timings env-configurable.

**Tech Stack:** TypeScript, bun:test (existing pattern), Node built-ins (`node:fs`, `node:os`, `node:path`). No new dependencies.

## Global Constraints

- No new dependencies; bun:test only (repo already uses it).
- Follow existing plugin patterns: `pi.registerProvider`/`registerCommand`, `pi.logger` warn-level logging, `stubFetch` test helper pattern from `test/extensions.test.ts`.
- Store schema: `{ version: 1, updatedAt: string, models: Record<string, { reasoning?, vision?, contextWindow?, maxTokens?, probedAt?, probeFailures?, contextScrapedAt? }> }` — exact served model ids as keys; `baseModelId` (in `extensions/discovery.ts`) strips a trailing `-\d{4}` before static-table lookups.
- Precedence: `reasoning` = store (known) → API `output` has `"thought"` → override/base-id match → `false`. `contextWindow` = store → static table (exact → base-id) → 128_000. `maxTokens` = store → 32_768. `vision` = API `input` only.
- Probe request: `POST {baseUrl}/chat/completions`, body `{ model, messages: [{role:"user", content:"Say OK"}], reasoning_effort: "high", max_tokens: 1, stream: true }`, Authorization `Bearer <key>`. Reasoning detected iff any SSE `delta` has a non-null `reasoning*` field.
- Config env vars (defaults): `SAIA_RECONCILE_STARTUP_DELAY_MS` (5000), `SAIA_RECONCILE_INTERVAL_MS` (21600000), `SAIA_RECONCILE_STALE_AFTER_MS` (43200000), `SAIA_RECONCILE_PROBES_PER_CYCLE` (2), `SAIA_RECONCILE_PROBE_TIMEOUT_MS` (20000), `SAIA_RECONCILE_REVERIFY_MS` (604800000), `SAIA_RECONCILE_SCRAPE_INTERVAL_MS` (604800000), `SAIA_RECONCILE_SCRAPE_TIMEOUT_MS` (15000), `SAIA_RECONCILE_STORE_PATH` (default `~/.omp/agent/saia-models.json`), `SAIA_RECONCILE_DISABLED` (unset). Invalid values (non-numeric, ≤0 where meaningless) fall back to defaults. Truthy `SAIA_RECONCILE_DISABLED` disables reconcile entirely.
- Atomic store writes: write `<path>.tmp`, then `rename`. Corrupt store on read: rename aside to `<path>.corrupt-<epoch-ms>` and return an empty store.
- Manual trigger: `/saia-refresh` slash command runs a full reconcile, awaited, and reports a one-line summary via `ctx.ui.notify`.
- Plan/spec location override: user global gitignore excludes `docs/superpowers/`, so docs live under repo `docs/` (spec already at `docs/2026-08-19-saia-model-reconciliation-design.md`).

---

### Task 1: Store schema and I/O

**Files:**
- Modify: `extensions/types.ts` (append store types)
- Create: `extensions/reconciler.ts` (store I/O only for now)
- Test: `test/reconciler.test.ts` (new file)

**Interfaces:**
- Produces: `ModelStore`, `StoredCapabilities` (from `extensions/types.ts`); `loadStore(path: string): ModelStore`; `saveStore(path: string, store: ModelStore): void`.

- [ ] **Step 1: Write the failing test**

```ts
// test/reconciler.test.ts
import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadStore, saveStore } from "../extensions/reconciler.js";
import type { ModelStore } from "../extensions/types.js";

function tempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "saia-store-"));
  return dir;
}

describe("store I/O", () => {
  test("save then load round-trips the store", () => {
    const dir = tempDir();
    try {
      const path = join(dir, "saia-models.json");
      const store: ModelStore = {
        version: 1,
        updatedAt: "2026-08-19T00:00:00.000Z",
        models: {
          "deepseek-v4-flash-0731": { reasoning: true, contextWindow: 1_000_000 },
        },
      };
      saveStore(path, store);
      expect(loadStore(path)).toEqual(store);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("missing store file loads as empty store", () => {
    const dir = tempDir();
    try {
      const store = loadStore(join(dir, "nope.json"));
      expect(store.version).toBe(1);
      expect(store.models).toEqual({});
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("corrupt store is quarantined and loads as empty", () => {
    const dir = tempDir();
    try {
      const path = join(dir, "saia-models.json");
      saveStore(path, { version: 1, updatedAt: "x", models: {} });
      // Corrupt it directly.
      const { writeFileSync } = require("node:fs");
      writeFileSync(path, "{ not json");
      const store = loadStore(path);
      expect(store.models).toEqual({});
      const files = require("node:fs").readdirSync(dir);
      expect(files.some((f: string) => f.startsWith("saia-models.json.corrupt-"))).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — `Cannot find module '../extensions/reconciler.js'` / `loadStore is not a function`.

- [ ] **Step 3: Add store types to `extensions/types.ts`**

Append to `extensions/types.ts`:

```ts
export interface StoredCapabilities {
  reasoning?: boolean;
  vision?: boolean;
  contextWindow?: number;
  maxTokens?: number;
  probedAt?: string;
  probeFailures?: number;
  contextScrapedAt?: string;
}

export interface ModelStore {
  version: 1;
  updatedAt: string;
  contextScrapedAt?: string;
  models: Record<string, StoredCapabilities>;
}
```

- [ ] **Step 4: Implement store I/O in `extensions/reconciler.ts`**

```ts
import { readFileSync, writeFileSync, renameSync, existsSync } from "node:fs";
import { dirname } from "node:path";
import type { ModelStore } from "./types.js";

const EMPTY_STORE: ModelStore = { version: 1, updatedAt: new Date(0).toISOString(), models: {} };

export function loadStore(path: string): ModelStore {
  if (!existsSync(path)) {
    return { ...EMPTY_STORE, models: {} };
  }
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as Partial<ModelStore>;
    if (parsed?.version !== 1 || typeof parsed.models !== "object" || parsed.models === null) {
      throw new Error("unexpected store shape");
    }
    return { version: 1, updatedAt: parsed.updatedAt ?? EMPTY_STORE.updatedAt, models: parsed.models as ModelStore["models"] };
  } catch {
    try {
      renameSync(path, `${path}.corrupt-${Date.now()}`);
    } catch {
      // quarantine is best-effort
    }
    return { ...EMPTY_STORE, models: {} };
  }
}

export function saveStore(path: string, store: ModelStore): void {
  const tmp = `${path}.tmp`;
  writeFileSync(tmp, JSON.stringify(store, null, 2));
  renameSync(tmp, path);
}
```

Note: `dirname` import is unused here — drop it. It will be used by Task 6/7 for mkdir; add `mkdirSync(dirname(path), { recursive: true })` in `saveStore` so parent dirs are created (the store dir may not exist yet).

- [ ] **Step 5: Run the test to verify it passes**

Run: `bun test test/reconciler.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add extensions/types.ts extensions/reconciler.ts test/reconciler.test.ts
git commit -m "feat: persisted model store with atomic I/O"
```

---

### Task 2: Config parsing

**Files:**
- Modify: `extensions/reconciler.ts`
- Test: `test/reconciler.test.ts`

**Interfaces:**
- Produces: `ReconcilerConfig`; `parseConfig(env: Record<string, string | undefined>): ReconcilerConfig`; `DEFAULT_CONFIG: ReconcilerConfig`.

- [ ] **Step 1: Write the failing test**

Append to `test/reconciler.test.ts`:

```ts
import { parseConfig, DEFAULT_CONFIG } from "../extensions/reconciler.js";

describe("config parsing", () => {
  test("defaults when env is empty", () => {
    const cfg = parseConfig({});
    expect(cfg).toEqual(DEFAULT_CONFIG);
  });

  test("applies numeric overrides", () => {
    const cfg = parseConfig({ SAIA_RECONCILE_INTERVAL_MS: "1000", SAIA_RECONCILE_PROBES_PER_CYCLE: "5" });
    expect(cfg.intervalMs).toBe(1000);
    expect(cfg.probesPerCycle).toBe(5);
  });

  test("invalid values fall back to defaults", () => {
    const cfg = parseConfig({ SAIA_RECONCILE_INTERVAL_MS: "abc", SAIA_RECONCILE_PROBE_TIMEOUT_MS: "-5", SAIA_RECONCILE_PROBES_PER_CYCLE: "0" });
    expect(cfg.intervalMs).toBe(DEFAULT_CONFIG.intervalMs);
    expect(cfg.probeTimeoutMs).toBe(DEFAULT_CONFIG.probeTimeoutMs);
    expect(cfg.probesPerCycle).toBe(DEFAULT_CONFIG.probesPerCycle);
  });

  test("store path override and disabled flag", () => {
    const cfg = parseConfig({ SAIA_RECONCILE_STORE_PATH: "/tmp/x.json", SAIA_RECONCILE_DISABLED: "1" });
    expect(cfg.storePath).toBe("/tmp/x.json");
    expect(cfg.disabled).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — `parseConfig is not a function` / `DEFAULT_CONFIG is undefined`.

- [ ] **Step 3: Implement config parsing**

Append to `extensions/reconciler.ts`:

```ts
import { homedir } from "node:os";
import { join } from "node:path";

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
    disabled: env.SAIA_RECONCILE_DISABLED !== undefined && env.SAIA_RECONCILE_DISABLED !== "" && env.SAIA_RECONCILE_DISABLED !== "0" && env.SAIA_RECONCILE_DISABLED.toLowerCase() !== "false",
  };
}
```

Also update `saveStore` from Task 1 to create parent dirs:

```ts
import { mkdirSync } from "node:fs";
// inside saveStore, before writeFileSync:
mkdirSync(dirname(path), { recursive: true });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bun test test/reconciler.test.ts`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add extensions/reconciler.ts test/reconciler.test.ts
git commit -m "feat: env-configurable reconcile timings"
```

---

### Task 3: Reasoning probe

**Files:**
- Modify: `extensions/reconciler.ts`
- Test: `test/reconciler.test.ts`

**Interfaces:**
- Produces: `parseProbeStream(chunks: string[]): boolean | null` (true = reasoning seen, false = clean text-only response, null = inconclusive/error); `probeReasoning(fetchImpl: typeof fetch, baseUrl: string, apiKey: string, modelId: string, timeoutMs: number): Promise<boolean | null>`.

- [ ] **Step 1: Write the failing test**

Append to `test/reconciler.test.ts`:

```ts
import { probeReasoning, parseProbeStream } from "../extensions/reconciler.js";

describe("reasoning probe", () => {
  test("parseProbeStream detects reasoning delta", () => {
    const chunks = [
      'data: {"choices":[{"delta":{"role":"assistant","content":""}}]}',
      'data: {"choices":[{"delta":{"reasoning":"We"}}]}',
      'data: {"choices":[{"delta":{"content":"OK"}}]}',
      "data: [DONE]",
    ];
    expect(parseProbeStream(chunks)).toBe(true);
  });

  test("parseProbeStream returns false for text-only", () => {
    const chunks = ['data: {"choices":[{"delta":{"content":"OK"}}]}', "data: [DONE]"];
    expect(parseProbeStream(chunks)).toBe(false);
  });

  test("parseProbeStream returns null on error chunk", () => {
    const chunks = ['data: {"error":{"message":"boom"}}'];
    expect(parseProbeStream(chunks)).toBe(null);
  });

  test("probeReasoning sends reasoning_effort and maps stream", async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const fakeFetch = (async (url: any, init: any) => {
      calls.push({ url, init });
      return new Response('data: {"choices":[{"delta":{"reasoning":"x"}}]}\ndata: [DONE]');
    }) as unknown as typeof fetch;
    const result = await probeReasoning(fakeFetch, "https://chat-ai.academiccloud.de/v1", "key", "m-1", 1000);
    expect(result).toBe(true);
    const body = JSON.parse(String(calls[0].init.body));
    expect(body.model).toBe("m-1");
    expect(body.reasoning_effort).toBe("high");
    expect(body.max_tokens).toBe(1);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Implement the probe**

Append to `extensions/reconciler.ts`:

```ts
export function parseProbeStream(chunks: string[]): boolean | null {
  let sawReasoning = false;
  let sawContent = false;
  for (const line of chunks) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("data:")) continue;
    const payload = trimmed.slice(5).trim();
    if (payload === "[DONE]") continue;
    let parsed: any;
    try {
      parsed = JSON.parse(payload);
    } catch {
      continue;
    }
    if (parsed.error) return null;
    const delta = parsed.choices?.[0]?.delta;
    if (!delta) continue;
    if (delta.reasoning !== undefined && delta.reasoning !== null) sawReasoning = true;
    if (delta.reasoning_content !== undefined && delta.reasoning_content !== null) sawReasoning = true;
    if (delta.reasoning_text !== undefined && delta.reasoning_text !== null) sawReasoning = true;
    if (delta.content !== undefined && delta.content !== null && delta.content !== "") sawContent = true;
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bun test test/reconciler.test.ts`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add extensions/reconciler.ts test/reconciler.test.ts
git commit -m "feat: reasoning probe with effort detection"
```

---

### Task 4: Docs scrape parsing

**Files:**
- Modify: `extensions/reconciler.ts`
- Test: `test/reconciler.test.ts`

**Interfaces:**
- Produces: `parseScrape(html: string): Record<string, number>` (model id → context length); `scrapeContextWindows(fetchImpl: typeof fetch, url: string, timeoutMs: number): Promise<Record<string, number> | null>`.

- [ ] **Step 1: Write the failing test**

Append to `test/reconciler.test.ts`:

```ts
import { parseScrape, scrapeContextWindows } from "../extensions/reconciler.js";

describe("docs scrape", () => {
  const HTML = `<html><body><table>
<tr><td>deepseek-v4-flash-0731</td><td>DeepSeek V4 Flash</td><td>1,000,000 tokens</td></tr>
<tr><td>qwen3.6-27b</td><td>Qwen 3.6 27B</td><td>262,000 tokens</td></tr>
<tr><td>broken-row</td><td>No number here</td></tr>
</table></body></html>`;

  test("parseScrape extracts context lengths", () => {
    const map = parseScrape(HTML);
    expect(map["deepseek-v4-flash-0731"]).toBe(1_000_000);
    expect(map["qwen3.6-27b"]).toBe(262_000);
  });

  test("parseScrape returns empty on malformed html", () => {
    expect(parseScrape("<html>no table")).toEqual({});
  });

  test("scrapeContextWindows fetches and parses", async () => {
    const fakeFetch = (async () => new Response(HTML)) as unknown as typeof fetch;
    const map = await scrapeContextWindows(fakeFetch, "https://docs.example/index.html", 1000);
    expect(map?.["qwen3.6-27b"]).toBe(262_000);
  });

  test("scrapeContextWindows returns null on http error", async () => {
    const fakeFetch = (async () => new Response("nope", { status: 500 })) as unknown as typeof fetch;
    const map = await scrapeContextWindows(fakeFetch, "https://docs.example/index.html", 1000);
    expect(map).toBe(null);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Implement the scraper**

Append to `extensions/reconciler.ts`:

```ts
const SCRAPE_URL = "https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html";

export function parseScrape(html: string): Record<string, number> {
  const result: Record<string, number> = {};
  const rows = html.match(/<tr[^>]*>[\s\S]*?<\/tr>/g) ?? [];
  for (const row of rows) {
    const cells = row.match(/<td[^>]*>([\s\S]*?)<\/td>/g) ?? [];
    if (cells.length < 3) continue;
    const id = stripTags(cells[0]).trim();
    const ctx = stripTags(cells[2]).replace(/,/g, "").match(/\d+/);
    if (id && ctx) {
      const n = Number(ctx[0]);
      if (Number.isInteger(n) && n > 0) result[id] = n;
    }
  }
  return result;
}

function stripTags(s: string): string {
  return s.replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").trim();
}

export async function scrapeContextWindows(
  fetchImpl: typeof fetch,
  url: string,
  timeoutMs: number,
): Promise<Record<string, number> | null> {
  const res = await fetchImpl(url, { signal: AbortSignal.timeout(timeoutMs) });
  if (!res.ok) return null;
  const html = await res.text();
  return parseScrape(html);
}
```

Note: the docs page layout may differ from the fixture (different column order, `K` suffixes like `262K`). `parseScrape` reads the third cell's first integer. If the live page uses `262K`, adjust the parser in this task to also handle `(\d+)\s*K` → ×1000. Verify against the live page during implementation and adapt `stripTags`/cell indexing accordingly, keeping the fixture tests aligned.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bun test test/reconciler.test.ts`
Expected: PASS (15 tests).

- [ ] **Step 5: Commit**

```bash
git add extensions/reconciler.ts test/reconciler.test.ts
git commit -m "feat: context-window docs scraper"
```

---

### Task 5: Discovery merge (store over static tables)

**Files:**
- Modify: `extensions/discovery.ts`
- Test: `test/extensions.test.ts` (append cases)

**Interfaces:**
- Consumes: `ModelStore` from `extensions/types.js`.
- Produces: `buildModelDefs(response: SaiaModelResponse, store?: ModelStore): ModelDef[]` — optional store param; when present, store values override static tables per precedence.

- [ ] **Step 1: Write the failing test**

Append inside the existing `describe("buildModelDefs", ...)` block in `test/extensions.test.ts`:

```ts
test("store values override static tables", () => {
  const store = {
    version: 1 as const,
    updatedAt: "2026-08-19T00:00:00.000Z",
    models: {
      "glm-4.7": { reasoning: false, contextWindow: 999_999 },
      "deepseek-v4-flash-0731": { reasoning: true, contextWindow: 1_000_000 },
    },
  };
  const response: SaiaModelResponse = {
    object: "list",
    data: [
      { id: "glm-4.7", name: "GLM 4.7", input: ["text"], output: ["thought", "text"], status: "ready" },
      { id: "deepseek-v4-flash-0731", name: "DeepSeek V4 Flash 0731", input: ["text"], output: ["text"], status: "ready" },
    ],
  };
  const defs = buildModelDefs(response, store);
  const glm = defs.find((d) => d.id === "glm-4.7")!;
  expect(glm.reasoning).toBe(false); // store overrides API "thought"
  expect(glm.contextWindow).toBe(999_999);
  const ds = defs.find((d) => d.id === "deepseek-v4-flash-0731")!;
  expect(ds.reasoning).toBe(true); // store overrides missing API signal
  expect(ds.contextWindow).toBe(1_000_000);
});

test("without store, behavior is unchanged", () => {
  const response: SaiaModelResponse = {
    object: "list",
    data: [{ id: "unknown-model", name: "X", input: ["text"], output: ["text"], status: "ready" }],
  };
  const defs = buildModelDefs(response);
  expect(defs[0].reasoning).toBe(false);
  expect(defs[0].contextWindow).toBe(128_000);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/extensions.test.ts`
Expected: FAIL — `buildModelDefs` called with 2 args ignores the store (store assertions fail).

- [ ] **Step 3: Implement the merge**

Modify `extensions/discovery.ts`:

```ts
import type { SaiaModelResponse, ModelDef } from "./types.js";
import type { ModelStore } from "./types.js"; // merged into the import above

export function buildModelDefs(response: SaiaModelResponse, store?: ModelStore): ModelDef[] {
  return response.data
    .filter((entry) => entry.status === "ready")
    .map((entry) => {
      const stored = store?.models[entry.id];
      return {
        id: entry.id,
        name: entry.name,
        reasoning: stored?.reasoning ?? supportsReasoning(entry),
        vision: entry.input?.includes("image") ?? false,
        contextWindow: stored?.contextWindow ?? resolveContextWindow(entry.id),
        maxTokens: stored?.maxTokens ?? DEFAULT_MAX_TOKENS,
      };
    });
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bun test` (whole suite — both files)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add extensions/discovery.ts test/extensions.test.ts
git commit -m "feat: merge persisted store over static capability tables"
```

---

### Task 6: Reconcile cycle logic (pure parts)

**Files:**
- Modify: `extensions/reconciler.ts`
- Test: `test/reconciler.test.ts`

**Interfaces:**
- Consumes: `SaiaModelResponse["data"]` entries; `ModelStore`; `ReconcilerConfig`; `baseModelId` (export it from `extensions/discovery.ts` if not already exported — it currently is module-private; export it in this task).
- Produces: `planProbes(store, list, config, now): string[]`; `applyProbeResult(store, id, reasoning: boolean | null): ModelStore`; `reconcileFields(store, list, scrapedContext: Record<string, number> | null, now): ModelStore`.

- [ ] **Step 1: Export `baseModelId` from `extensions/discovery.ts`**

```ts
// extensions/discovery.ts — change `function baseModelId` to `export function baseModelId`
```

- [ ] **Step 2: Write the failing test**

Append to `test/reconciler.test.ts`:

```ts
import { planProbes, applyProbeResult, reconcileFields } from "../extensions/reconciler.js";
import { baseModelId } from "../extensions/discovery.js";
// NOTE: `SaiaModelResponse` is used in this block — add `import type { SaiaModelResponse } from "../extensions/types.js";` if not already imported.

describe("reconcile cycle logic", () => {
  const config = { ...DEFAULT_CONFIG, probesPerCycle: 2, reverifyMs: 604_800_000 };
  const list = [
    { id: "a-1", name: "A", input: ["text", "image"], output: ["thought", "text"], status: "ready" },
    { id: "unknown-1", name: "U1", input: ["text"], output: ["text"], status: "ready" },
    { id: "unknown-2", name: "U2", input: ["text"], output: ["text"], status: "ready" },
    { id: "unknown-3", name: "U3", input: ["text"], output: ["text"], status: "ready" },
  ] as SaiaModelResponse["data"];
  const now = new Date("2026-08-19T00:00:00.000Z");

  test("planProbes picks unknown models up to the budget, skips known and recent", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: {
        "unknown-1": { reasoning: true, probedAt: now.toISOString() },
      },
    };
    const probes = planProbes(store, list, config, now);
    expect(probes).toEqual(["unknown-2", "unknown-3"]); // unknown-1 known, budget 2
  });

  test("planProbes skips models whose re-verify is not due", () => {
    const due = new Date(now.getTime() - 2 * 604_800_000).toISOString();
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, probedAt: due } },
    };
    expect(planProbes(store, list, config, now)).toEqual(["unknown-2", "unknown-3"]);
  });

  test("planProbes backoff: recent failure defers re-probe (no hammering)", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, probedAt: now.toISOString(), probeFailures: 3 } },
    };
    expect(planProbes(store, list, config, now)).not.toContain("unknown-1");
    // ...but a failure from long ago is due again at the weekly cadence.
    const old = new Date(now.getTime() - 2 * 604_800_000).toISOString();
    const oldStore: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, probedAt: old, probeFailures: 3 } },
    };
    expect(planProbes(oldStore, list, config, now)).toContain("unknown-1");
  });

  test("applyProbeResult records reasoning and failure backoff", () => {
    let store: ModelStore = { version: 1, updatedAt: now.toISOString(), models: {} };
    store = applyProbeResult(store, "m-1", true, now);
    expect(store.models["m-1"].reasoning).toBe(true);
    expect(store.models["m-1"].probeFailures).toBe(0);
    store = applyProbeResult(store, "m-2", null, now);
    expect(store.models["m-2"].reasoning).toBeUndefined();
    expect(store.models["m-2"].probeFailures).toBe(1);
  });

  test("reconcileFields applies API vision, store reasoning, scraped context", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, contextWindow: 555_555 } },
    };
    const scraped = { "unknown-2": 262_000 };
    const merged = reconcileFields(store, list, scraped, now);
    expect(merged.models["a-1"].vision).toBe(true);
    expect(merged.models["a-1"].reasoning).toBe(true); // from API "thought"
    expect(merged.models["unknown-1"].reasoning).toBe(true); // kept from store
    expect(merged.models["unknown-1"].contextWindow).toBe(555_555); // store wins over scrape
    expect(merged.models["unknown-2"].contextWindow).toBe(262_000); // scrape fills unknown
    expect(merged.updatedAt).toBe(now.toISOString());
  });

  test("baseModelId strips date stamp", () => {
    expect(baseModelId("deepseek-v4-flash-0731")).toBe("deepseek-v4-flash");
    expect(baseModelId("qwen3.6-27b")).toBe("qwen3.6-27b");
  });
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — functions not defined.

- [ ] **Step 4: Implement the cycle logic**

Append to `extensions/reconciler.ts`:

```ts
import { baseModelId, REASONING_OVERRIDES } from "./discovery.js"; // export REASONING_OVERRIDES from discovery.ts in this task (add `export` to its declaration)
import type { SaiaModelResponse, StoredCapabilities } from "./types.js";

export function planProbes(
  store: ModelStore,
  list: SaiaModelResponse["data"],
  config: ReconcilerConfig,
  now: Date,
): string[] {
  const probes: string[] = [];
  for (const entry of list) {
    if (probes.length >= config.probesPerCycle) break;
    const id = entry.id;
    if (entry.output?.includes("thought")) continue; // authoritative
    if (REASONING_OVERRIDES.has(id) || REASONING_OVERRIDES.has(baseModelId(id))) continue; // authoritative
    const stored = store.models[id];
    const probedAt = stored?.probedAt ? new Date(stored.probedAt).getTime() : 0;
    // Backoff: a recent probe (success OR failure) defers the next probe until
    // reverifyMs elapses — applyProbeResult sets probedAt on failure too, so a
    // failing model is not re-probed every cycle. probeFailures stays as
    // bookkeeping; the ≥3 threshold adds no extra gating beyond probedAt
    // (spec's "back off to weekly" = the reverifyMs gate).
    const due = probedAt === 0 || probedAt + config.reverifyMs <= now.getTime();
    if (due) probes.push(id);
  }
  return probes;
}

export function applyProbeResult(store: ModelStore, id: string, reasoning: boolean | null, now: Date): ModelStore {
  const entry = store.models[id] ?? {};
  if (reasoning === null) {
    return { ...store, models: { ...store.models, [id]: { ...entry, probedAt: now.toISOString(), probeFailures: (entry.probeFailures ?? 0) + 1 } } };
  }
  return { ...store, models: { ...store.models, [id]: { ...entry, reasoning, probedAt: now.toISOString(), probeFailures: 0 } } };
}

export function reconcileFields(
  store: ModelStore,
  list: SaiaModelResponse["data"],
  scrapedContext: Record<string, number> | null,
  now: Date,
): ModelStore {
  const models: ModelStore["models"] = { ...store.models };
  for (const entry of list) {
    const existing = models[entry.id] ?? {};
    const next: StoredCapabilities = { ...existing };
    if (entry.input?.includes("image")) next.vision = true;
    else if (entry.input?.length) next.vision = false;
    if (entry.output?.includes("thought")) next.reasoning = true;
    else if (REASONING_OVERRIDES.has(entry.id) || REASONING_OVERRIDES.has(baseModelId(entry.id))) next.reasoning = true;
    if (scrapedContext?.[entry.id] !== undefined) next.contextWindow = scrapedContext[entry.id];
    models[entry.id] = next;
  }
  return { version: 1, updatedAt: now.toISOString(), models };
}
```

Note: `supportsReasoning` in discovery.ts already encodes the API+override check; `reconcileFields` re-encodes it to stay pure and import-free of discovery internals beyond `baseModelId`/`REASONING_OVERRIDES` (export both). If that coupling is undesirable, export `supportsReasoning` instead and call it per entry.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bun test`
Expected: PASS (both files).

- [ ] **Step 6: Commit**

```bash
git add extensions/reconciler.ts extensions/discovery.ts test/reconciler.test.ts
git commit -m "feat: probe planning, result application, and field reconciliation"
```

---

### Task 7: Runtime wiring — reconciler lifecycle + discovery integration + slash command

**Files:**
- Modify: `extensions/reconciler.ts` (createReconciler), `extensions/index.ts`
- Modify: `extensions/constants.ts` (SCRAPE_URL lives in reconciler.ts; no change needed here — skip unless a constant is duplicated)
- Test: `test/reconciler.test.ts` (lifecycle), `test/extensions.test.ts` (command registration)

**Interfaces:**
- Consumes: `parseConfig`, `loadStore`, `saveStore`, `planProbes`, `applyProbeResult`, `reconcileFields`, `probeReasoning`, `scrapeContextWindows`, `fetchModels` (from discovery.js).
- Produces: `createReconciler(deps): { start(): void; reconcileNow(): Promise<ReconcileSummary>; stop(): void }` where `deps = { config: ReconcilerConfig; getApiKey(): string | undefined; fetchImpl?: typeof fetch; setInterval?: typeof setInterval; clearInterval?: typeof clearInterval; setTimeout?: typeof setTimeout; clearTimeout?: typeof clearTimeout; logger: { warn(msg: string, extra?: unknown): void }; onNotify?: (msg: string) => void }`; `ReconcileSummary = { modelsSeen: number; probesRun: number; probeFailures: number; scraped: boolean }`.

- [ ] **Step 1: Write the failing lifecycle test**

Append to `test/reconciler.test.ts`:

```ts
import { createReconciler } from "../extensions/reconciler.js";
import type { ReconcileSummary } from "../extensions/reconciler.js";

describe("reconciler lifecycle", () => {
  test("reconcileNow runs one cycle with single-flight", async () => {
    let modelsCalls = 0;
    const fakeFetch = (async (url: any) => {
      if (String(url).endsWith("/models")) {
        modelsCalls++;
        return new Response(JSON.stringify({ object: "list", data: [] }));
      }
      // scrape URL (first cycle: store empty → scrape due)
      return new Response("<html><table><tr><td>none</td><td>x</td><td>1,000</td></tr></table></html>");
    }) as unknown as typeof fetch;
    const reconciler = createReconciler({
      config: { ...DEFAULT_CONFIG, storePath: "/tmp/nonexistent-dir-x/saia.json", probesPerCycle: 1 },
      getApiKey: () => "key",
      fetchImpl: fakeFetch,
      logger: { warn: () => {} },
    });
    const first = reconciler.reconcileNow();
    const second = reconciler.reconcileNow();
    const [a, b] = await Promise.all([first, second]);
    expect(a).toEqual(b); // single-flight: same promise result
    expect(modelsCalls).toBe(1); // only one /models fetch despite two calls
    reconciler.stop();
  });

  test("start defers and schedules interval", async () => {
    const timeouts: Array<{ fn: () => void; ms: number }> = [];
    const intervals: Array<{ fn: () => void; ms: number }> = [];
    const fakeTimers = {
      setTimeout: (fn: () => void, ms: number) => { timeouts.push({ fn, ms }); return 1 as unknown as ReturnType<typeof setTimeout>; },
      clearTimeout: () => {},
      setInterval: (fn: () => void, ms: number) => { intervals.push({ fn, ms }); return 2 as unknown as ReturnType<typeof setInterval>; },
      clearInterval: () => {},
    };
    const reconciler = createReconciler({
      config: { ...DEFAULT_CONFIG, storePath: "/tmp/nonexistent-dir-x/saia.json" },
      getApiKey: () => "key",
      logger: { warn: () => {} },
      ...fakeTimers,
    });
    reconciler.start();
    expect(timeouts).toHaveLength(1);
    expect(timeouts[0].ms).toBe(DEFAULT_CONFIG.startupDelayMs);
    expect(intervals).toHaveLength(1);
    expect(intervals[0].ms).toBe(DEFAULT_CONFIG.intervalMs);
    reconciler.stop();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test test/reconciler.test.ts`
Expected: FAIL — `createReconciler is not a function`.

- [ ] **Step 3: Implement `createReconciler`**

Append to `extensions/reconciler.ts`:

```ts
import { fetchModels } from "./discovery.js";

export interface ReconcileSummary {
  modelsSeen: number;
  probesRun: number;
  probeFailures: number;
  scraped: boolean;
}

export interface ReconcilerDeps {
  config: ReconcilerConfig;
  getApiKey: () => string | undefined;
  fetchImpl?: typeof fetch;
  setInterval?: typeof setInterval;
  clearInterval?: typeof clearInterval;
  setTimeout?: typeof setTimeout;
  clearTimeout?: typeof clearTimeout;
  logger: { warn: (msg: string, extra?: unknown) => void };
}

export function createReconciler(deps: ReconcilerDeps) {
  const { config } = deps;
  const fetchImpl = deps.fetchImpl ?? fetch;
  const setIntervalFn = deps.setInterval ?? setInterval;
  const clearIntervalFn = deps.clearInterval ?? clearInterval;
  const setTimeoutFn = deps.setTimeout ?? setTimeout;
  const clearTimeoutFn = deps.clearTimeout ?? clearTimeout;

  let running: Promise<ReconcileSummary> | null = null;
  let intervalId: ReturnType<typeof setInterval> | null = null;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  async function cycle(): Promise<ReconcileSummary> {
    const apiKey = deps.getApiKey();
    if (!apiKey) {
      deps.logger.warn("[SAIA] No API key; skipping reconcile");
      return { modelsSeen: 0, probesRun: 0, probeFailures: 0, scraped: false };
    }
    let list;
    try {
      list = await fetchModels(apiKey);
    } catch (error) {
      deps.logger.warn("[SAIA] Reconcile: model list fetch failed", { error: error instanceof Error ? error.message : String(error) });
      return { modelsSeen: 0, probesRun: 0, probeFailures: 0, scraped: false };
    }
    const now = new Date();
    let store = loadStore(config.storePath);

    // Scrape context windows when due (weekly) — best-effort.
    let scrapedContext: Record<string, number> | null = null;
    const lastScrape = store.contextScrapedAt ? new Date(store.contextScrapedAt).getTime() : 0;
    const scrapeDue = lastScrape === 0 || lastScrape + config.scrapeIntervalMs <= now.getTime();
    if (scrapeDue) {
      try {
        scrapedContext = await scrapeContextWindows(fetchImpl, SCRAPE_URL, config.scrapeTimeoutMs);
        if (scrapedContext !== null && Object.keys(scrapedContext).length > 0) {
          store = { ...store, contextScrapedAt: now.toISOString() };
        }
      } catch (error) {
        deps.logger.warn("[SAIA] Reconcile: context scrape failed", { error: String(error) });
      }
    }

    // Probe unknown/due models, bounded.
    const probes = planProbes(store, list.data, config, now);
    let probesRun = 0;
    let probeFailures = 0;
    for (const id of probes) {
      const result = await probeReasoning(fetchImpl, BASE_URL, apiKey, id, config.probeTimeoutMs);
      store = applyProbeResult(store, id, result, now);
      probesRun++;
      if (result === null) probeFailures++;
    }

    store = reconcileFields(store, list.data, scrapedContext, now);
    store.updatedAt = now.toISOString();
    saveStore(config.storePath, store);
    return { modelsSeen: list.data.length, probesRun, probeFailures, scraped: false };
  }

  return {
    start(): void {
      if (config.disabled) return;
      // Catch-up: run the deferred startup cycle only when the store is stale
      // (older than staleAfterMs) or missing; a fresh store just waits for the
      // interval. This is what makes SAIA_RECONCILE_STALE_AFTER_MS meaningful.
      const store = loadStore(config.storePath);
      const updatedAt = store.updatedAt ? new Date(store.updatedAt).getTime() : 0;
      const fresh = updatedAt > 0 && Date.now() - updatedAt < config.staleAfterMs;
      if (!fresh) {
        timeoutId = setTimeoutFn(() => {
          cycle().catch((error) => deps.logger.warn("[SAIA] Reconcile cycle error", { error: String(error) }));
        }, config.startupDelayMs);
      }
      intervalId = setIntervalFn(() => {
        cycle().catch((error) => deps.logger.warn("[SAIA] Reconcile cycle error", { error: String(error) }));
      }, config.intervalMs);
    },
    reconcileNow(): Promise<ReconcileSummary> {
      if (!running) {
        running = cycle().finally(() => { running = null; });
      }
      return running;
    },
    stop(): void {
      if (timeoutId !== null) clearTimeoutFn(timeoutId);
      if (intervalId !== null) clearIntervalFn(intervalId);
    },
  };
}
```

**Imports needed at the top of `extensions/reconciler.ts` for this task:**

```ts
import { BASE_URL } from "./constants.js";
import { SCRAPE_URL } from "./constants.js";   // add `export const SCRAPE_URL = "https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html";` to constants.ts (or keep SCRAPE_URL local to reconciler.ts — either is fine, but define it once)
import { fetchModels } from "./discovery.js";
```

The `a === b` single-flight assertion requires `reconcileNow` to return the SAME promise object — the implementation above does that via the `running` cache; `.finally` resets `running`. `fetchModels(apiKey)` matches the existing signature in discovery.ts.

- [ ] **Step 4: Wire the slash command and startup in `extensions/index.ts`**

Modify `extensions/index.ts`:

```ts
import { parseConfig, createReconciler } from "./reconciler.js";

export default function (pi: ExtensionAPI) {
  const envKey = process.env.SAIA_API_KEY?.trim();
  const logger = pi.logger;
  const config = parseConfig(process.env as Record<string, string | undefined>);
  const reconciler = createReconciler({
    config,
    getApiKey: () => process.env.SAIA_API_KEY?.trim(),
    logger,
  });

  pi.registerProvider(PROVIDER_ID, {
    baseUrl: BASE_URL,
    api: "openai-completions",
    ...(envKey ? { apiKey: envKey } : {}),
    fetchDynamicModels: async (resolvedKey) => {
      const apiKey = resolvedKey ?? process.env.SAIA_API_KEY?.trim();
      if (!apiKey) {
        logger.warn("[SAIA] No API key available; SAIA models are disabled. Set SAIA_API_KEY and run `omp models`.");
        return [];
      }
      try {
        const response = await fetchModels(apiKey);
        const store = loadStore(config.storePath);
        return buildModelDefs(response, store).map(toModelConfig);
      } catch (error) {
        logger.warn("[SAIA] Failed to fetch models from API", { error: error instanceof Error ? error.message : String(error) });
        return [];
      }
    },
  });

  pi.registerCommand("saia-refresh", {
    description: "Reconcile SAIA model capabilities now (list, reasoning, vision, context windows)",
    handler: async (_args: unknown, ctx: { ui: { notify: (msg: string, level?: string) => void } }) => {
      const summary = await reconciler.reconcileNow();
      const msg = `[SAIA] reconcile: ${summary.modelsSeen} models, ${summary.probesRun} probes, ${summary.probeFailures} failures, scraped=${summary.scraped}. Run 'omp models refresh' to surface.`;
      ctx.ui.notify(msg, "info");
    },
  });

  reconciler.start();
}
```

Add imports: `loadStore`, `buildModelDefs` (already imported? index.ts currently imports `fetchModels, buildModelDefs` — keep), `toModelConfig` (already imported).

- [ ] **Step 5: Extend the command-registration test**

In `test/extensions.test.ts`, inside the `extension factory` describe, extend the existing registration test or add:

```ts
test("registers the saia-refresh slash command", () => {
  const { pi, registrations } = fakePi();
  extensionFactory(pi as unknown as ExtensionAPI);
  const cmd = registrations.find((r) => r.type === "command");
  expect(cmd).toBeDefined();
  expect((cmd as { name: string }).name).toBe("saia-refresh");
});
```

Check the existing `Registration` interface in the test file and extend it with a `command` variant if needed.

- [ ] **Step 6: Run the full suite**

Run: `bun test`
Expected: PASS (all files). Also run `bun x tsc --noEmit -p tsconfig.json` from `/tmp` (sandbox cwd restriction) — expected rc=0.

- [ ] **Step 7: Commit**

```bash
git add extensions/index.ts extensions/reconciler.ts extensions/types.ts test/reconciler.test.ts test/extensions.test.ts
git commit -m "feat: background reconciler lifecycle, discovery merge, /saia-refresh command"
```

---

### Task 8: Docs and changelog

**Files:**
- Modify: `README.md`, `skills/saia-models/SKILL.md`, `CHANGELOG.md`
- Modify: `docs/2026-08-19-saia-model-reconciliation-design.md` (if implementation diverged from spec, note it)

- [ ] **Step 1: Add a README section after "Usage"**

```markdown
## Automatic capability reconciliation

The plugin keeps model capabilities (reasoning, vision, context windows) fresh in the background: a deferred cycle at startup, then every 6 h while omp runs. Each cycle refreshes the model list, probes unknown models for reasoning (tiny ~2-token calls, ≤2 per cycle), re-scrapes SAIA's docs page weekly for context windows, and stores the result in `~/.omp/agent/saia-models.json`. omp picks the fresh data up at its next model discovery (`omp models` / `omp models refresh`).

Trigger a reconcile manually: `/saia-refresh` — then `omp models refresh` to surface the result immediately.

All timings are env-configurable (invalid values fall back to defaults):

| Variable | Default | Meaning |
|---|---|---|
| `SAIA_RECONCILE_STARTUP_DELAY_MS` | `5000` | defer reconcile after session start |
| `SAIA_RECONCILE_INTERVAL_MS` | `21600000` | background cycle (6 h) |
| `SAIA_RECONCILE_STALE_AFTER_MS` | `43200000` | catch-up at startup if store older |
| `SAIA_RECONCILE_PROBES_PER_CYCLE` | `2` | probe budget per cycle |
| `SAIA_RECONCILE_PROBE_TIMEOUT_MS` | `20000` | per-probe timeout |
| `SAIA_RECONCILE_REVERIFY_MS` | `604800000` | per-model re-verify (7 d) |
| `SAIA_RECONCILE_SCRAPE_INTERVAL_MS` | `604800000` | docs scrape cadence (7 d) |
| `SAIA_RECONCILE_SCRAPE_TIMEOUT_MS` | `15000` | scrape fetch timeout |
| `SAIA_RECONCILE_STORE_PATH` | `~/.omp/agent/saia-models.json` | store location |
| `SAIA_RECONCILE_DISABLED` | unset | set to any truthy value to disable |

Failures degrade silently to the last known state or the static tables; nothing blocks startup or discovery.
```

- [ ] **Step 2: Add a short note to `skills/saia-models/SKILL.md`**

```markdown
## Automatic updates

Capabilities reconcile automatically in the background (startup + every 6 h) and are stored in `~/.omp/agent/saia-models.json`; env vars `SAIA_RECONCILE_*` tune timing and location. Run `/saia-refresh` to reconcile immediately, then `omp models refresh` to surface the result.
```

- [ ] **Step 3: Add a CHANGELOG entry**

Under `## [Unreleased]` → `### Added`:

```markdown
- Automatic capability reconciliation: background cycle (startup + interval) keeps model list, reasoning, vision, and context windows fresh in a persisted store; env-configurable timing (`SAIA_RECONCILE_*`); manual `/saia-refresh` command
```

- [ ] **Step 4: Verify docs render and commit**

Read back the README section, confirm the table is well-formed, then:

```bash
git add README.md skills/saia-models/SKILL.md CHANGELOG.md
git commit -m "docs: reconcile configuration and /saia-refresh command"
```

---

### Task 9: omp discovery-cache TTL investigation (spec non-goal)

**Files:**
- Modify: `docs/2026-08-19-saia-model-reconciliation-design.md` (record the finding)
- Modify: `README.md` (only if a knob is found)

**Interfaces:**
- Produces: a written conclusion in the spec's Non-goals section.

- [ ] **Step 1: Investigate the TTL**

The spec's non-goal says omp's extension API exposes no model-cache TTL knob. Verify whether `@oh-my-pi/pi-coding-agent` (or the catalog package it re-exports) exposes any per-provider discovery TTL:

```bash
# In the repo, inspect the installed dev dependency for a TTL constant or discovery option:
grep -rn -i "ttl\|24 \* 60\|cache.*ms" node_modules/@oh-my-pi/pi-coding-agent/dist 2>/dev/null | grep -i "model\|discover" | head -20
# Also check the extension API types for any refresh/invalidate surface:
grep -rn "refresh\|invalidate" node_modules/@oh-my-pi/pi-coding-agent/dist/*.d.ts 2>/dev/null | head
```

If the package ships only compiled bundles, note that in the conclusion and try `omp config get` for a related key:

```bash
omp config list 2>&1 | grep -i "ttl\|discover\|model" | head
```

- [ ] **Step 2: Record the conclusion**

Append to the spec's Non-goals section (keep it to 2-3 sentences):

- If a knob exists: name it, its default, and how a user sets it (e.g. `omp config set <key> <value>`), and note it in the README.
- If not (expected): one sentence stating the reconciler's store keeps data fresh so any omp re-discovery lands on fresh data, and that shortening omp's 24h cache would require an upstream omp feature.

- [ ] **Step 3: Commit**

```bash
git add docs/2026-08-19-saia-model-reconciliation-design.md README.md
git commit -m "docs: record omp model-cache TTL investigation conclusion"
```

---

## Final verification (after Task 9)

Run from the repo (bun at `/home/joe/tmp/bun/bin/bun` if not on PATH):

```bash
bun test                 # full suite, all files
cd /tmp && bun x tsc --noEmit -p /home/joe/tmp/omp-saia-plugin/tsconfig.json   # typecheck (sandbox: run from /tmp)
```

Expected: all tests pass, tsc rc=0.

Optional live smoke test (requires `SAIA_API_KEY` and a writable store path):

```bash
SAIA_RECONCILE_STORE_PATH=/tmp/saia-smoke.json omp -p --no-session --model saia/deepseek-v4-flash-0731 --thinking high --print-thoughts --max-time 150 "Reply with exactly: OK"
```

Then inspect `/tmp/saia-smoke.json` — expect `deepseek-v4-flash-0731` with `reasoning: true` and a context window, and `/saia-refresh` reported via the command handler in an interactive session.
