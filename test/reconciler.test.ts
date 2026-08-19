import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, existsSync, writeFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadStore, saveStore } from "../extensions/reconciler.js";
import type { ModelStore } from "../extensions/types.js";

function tempDir(): string {
  return mkdtempSync(join(tmpdir(), "saia-store-"));
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
      // atomic write leaves no tmp sibling behind
      expect(existsSync(`${path}.tmp`)).toBe(false);
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

  test("save creates parent directories", () => {
    const dir = tempDir();
    try {
      const path = join(dir, "deep", "nested", "saia-models.json");
      saveStore(path, { version: 1, updatedAt: "x", models: {} });
      expect(existsSync(path)).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("corrupt store is quarantined and loads as empty", () => {
    const dir = tempDir();
    try {
      const path = join(dir, "saia-models.json");
      writeFileSync(path, "{ not json");
      const store = loadStore(path);
      expect(store.models).toEqual({});
      const files = readdirSync(dir);
      expect(files.some((f) => f.startsWith("saia-models.json.corrupt-"))).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("wrong-shape store is quarantined too", () => {
    const dir = tempDir();
    try {
      const path = join(dir, "saia-models.json");
      writeFileSync(path, JSON.stringify({ version: 2, models: [] }));
      const store = loadStore(path);
      expect(store.models).toEqual({});
      // original file was renamed aside, not left in place
      expect(existsSync(path)).toBe(false);
      expect(readdirSync(dir).some((f) => f.startsWith("saia-models.json.corrupt-"))).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

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
    const cfg = parseConfig({
      SAIA_RECONCILE_INTERVAL_MS: "abc",
      SAIA_RECONCILE_PROBE_TIMEOUT_MS: "-5",
      SAIA_RECONCILE_PROBES_PER_CYCLE: "0",
    });
    expect(cfg.intervalMs).toBe(DEFAULT_CONFIG.intervalMs);
    expect(cfg.probeTimeoutMs).toBe(DEFAULT_CONFIG.probeTimeoutMs);
    expect(cfg.probesPerCycle).toBe(DEFAULT_CONFIG.probesPerCycle);
  });

  test("store path override and disabled flag", () => {
    const cfg = parseConfig({ SAIA_RECONCILE_STORE_PATH: "/tmp/x.json", SAIA_RECONCILE_DISABLED: "1" });
    expect(cfg.storePath).toBe("/tmp/x.json");
    expect(cfg.disabled).toBe(true);
  });

  test("disabled flag treats false/0 as enabled", () => {
    expect(parseConfig({ SAIA_RECONCILE_DISABLED: "0" }).disabled).toBe(false);
    expect(parseConfig({ SAIA_RECONCILE_DISABLED: "false" }).disabled).toBe(false);
  });
});

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

  test("parseProbeStream handles reasoning_content and reasoning_text fields", () => {
    expect(parseProbeStream(['data: {"choices":[{"delta":{"reasoning_content":"x"}}]}'])).toBe(true);
    expect(parseProbeStream(['data: {"choices":[{"delta":{"reasoning_text":"x"}}]}'])).toBe(true);
  });

  test("parseProbeStream returns false for text-only", () => {
    const chunks = ['data: {"choices":[{"delta":{"content":"OK"}}]}', "data: [DONE]"];
    expect(parseProbeStream(chunks)).toBe(false);
  });

  test("parseProbeStream returns null on error chunk", () => {
    const chunks = ['data: {"error":{"message":"boom"}}'];
    expect(parseProbeStream(chunks)).toBe(null);
  });

  test("parseProbeStream returns null on empty stream", () => {
    expect(parseProbeStream([])).toBe(null);
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
    expect(body.stream).toBe(true);
  });

  test("probeReasoning returns null on non-ok response", async () => {
    const fakeFetch = (async () => new Response("nope", { status: 500 })) as unknown as typeof fetch;
    const result = await probeReasoning(fakeFetch, "https://x/v1", "key", "m-1", 1000);
    expect(result).toBe(null);
  });
});

import { parseScrape, scrapeContextWindows, matchScrapedContext, normalizeModelName } from "../extensions/reconciler.js";

const DOCS_HTML = `<html><body><table>
<tr><td>🇨🇳 DeepSeek</td><td>DeepSeek V4 Flash 0731</td><td>yes</td><td>Jul 2026</td><td>1M</td><td>Great overall performance</td><td>-</td><td>temp=1.0, top_p=1.0</td></tr>
<tr><td>🇩🇪 Qwen</td><td>Qwen 3.6 27B</td><td>yes</td><td>Apr 2026</td><td>262K</td><td>Vision</td><td>-</td><td>default</td></tr>
<tr><td>🇩🇪 Apertus</td><td>Apertus 70B Instruct 2509</td><td>yes</td><td>Sep 2025</td><td>65k</td><td>Open source</td><td>-</td><td>temp=0.8</td></tr>
<tr><td>🇺🇸 Meta</td><td>Llama 3.1 8B Instruct</td><td>yes</td><td>Jul 2024</td><td>128k</td><td>General</td><td>-</td><td>default</td></tr>
<tr><td>🇩🇪 X</td><td>broken-row</td><td>no</td></tr>
</table></body></html>`;

describe("docs scrape", () => {
  test("normalizeModelName collapses case and separators", () => {
    expect(normalizeModelName("DeepSeek V4 Flash 0731")).toBe("deepseek-v4-flash-0731");
    expect(normalizeModelName("GLM-4.7")).toBe("glm-4-7");
    expect(normalizeModelName("Qwen 3.6 27B")).toBe("qwen-3-6-27b");
  });

  test("parseScrape extracts contexts keyed by normalized name", () => {
    const map = parseScrape(DOCS_HTML);
    expect(map["deepseek-v4-flash-0731"]).toBe(1_000_000);
    expect(map["qwen-3-6-27b"]).toBe(262_000);
    expect(map["apertus-70b-instruct-2509"]).toBe(65_000);
    expect(map["llama-3-1-8b-instruct"]).toBe(128_000);
  });

  test("parseScrape returns empty on malformed html", () => {
    expect(parseScrape("<html>no table")).toEqual({});
  });

  test("matchScrapedContext finds exact and containment matches", () => {
    const map = { "gpt-oss-120b": 128_000, "glm-4-7": 200_000 };
    expect(matchScrapedContext(map, "OpenAI GPT OSS 120B")).toBe(128_000);
    expect(matchScrapedContext(map, "GLM-4.7")).toBe(200_000);
    expect(matchScrapedContext(map, "DeepSeek V4 Flash 0731")).toBeUndefined();
  });

  test("scrapeContextWindows fetches and parses", async () => {
    const fakeFetch = (async () => new Response(DOCS_HTML)) as unknown as typeof fetch;
    const map = await scrapeContextWindows(fakeFetch, "https://docs.example/index.html", 1000);
    expect(map?.["qwen-3-6-27b"]).toBe(262_000);
  });

  test("scrapeContextWindows returns null on http error", async () => {
    const fakeFetch = (async () => new Response("nope", { status: 500 })) as unknown as typeof fetch;
    const map = await scrapeContextWindows(fakeFetch, "https://docs.example/index.html", 1000);
    expect(map).toBe(null);
  });
});

import { planProbes, applyProbeResult, reconcileFields } from "../extensions/reconciler.js";
import { baseModelId } from "../extensions/discovery.js";
import type { SaiaModelResponse } from "../extensions/types.js";

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
      models: { "unknown-1": { reasoning: true, probedAt: now.toISOString() } },
    };
    expect(planProbes(store, list, config, now)).toEqual(["unknown-2", "unknown-3"]);
  });

  test("planProbes skips authoritative and recently-probed models", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: {},
    };
    const probes = planProbes(store, list, config, now);
    // a-1 advertises "thought" -> never probed
    expect(probes).not.toContain("a-1");
    expect(probes.length).toBe(config.probesPerCycle);
  });

  test("planProbes backoff: recent failure defers re-probe (no hammering)", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, probedAt: now.toISOString(), probeFailures: 3 } },
    };
    expect(planProbes(store, list, config, now)).not.toContain("unknown-1");
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
    expect(store.models["m-2"].probedAt).toBe(now.toISOString());
  });

  test("reconcileFields applies API vision/reasoning and scraped context by name", () => {
    const store: ModelStore = {
      version: 1,
      updatedAt: now.toISOString(),
      models: { "unknown-1": { reasoning: true, contextWindow: 555_555 } },
    };
    const scraped = { u2: 262_000 }; // normalizeModelName("U2") === "u2"
    const merged = reconcileFields(store, list, scraped, now);
    expect(merged.models["a-1"].vision).toBe(true);
    expect(merged.models["a-1"].reasoning).toBe(true); // from API "thought"
    expect(merged.models["unknown-1"].reasoning).toBe(true); // kept from store
    expect(merged.models["unknown-1"].contextWindow).toBe(555_555); // no scraped match -> store kept
    expect(merged.models["unknown-2"].contextWindow).toBe(262_000); // scraped fills by name match
    expect(merged.updatedAt).toBe(now.toISOString());
  });

  test("baseModelId strips date stamp", () => {
    expect(baseModelId("deepseek-v4-flash-0731")).toBe("deepseek-v4-flash");
    expect(baseModelId("qwen3.6-27b")).toBe("qwen3.6-27b");
  });
});

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
      // scrape URL (first cycle: store empty -> scrape due)
      return new Response(
        "<html><table><tr><td>X</td><td>Some Model</td><td>yes</td><td>2026</td><td>1M</td><td>-</td><td>-</td><td>-</td></tr></table></html>",
      );
    }) as unknown as typeof fetch;
    const dir = mkdtempSync(join(tmpdir(), "saia-singleflight-"));
    const reconciler = createReconciler({
      config: { ...DEFAULT_CONFIG, storePath: join(dir, "saia.json"), probesPerCycle: 1 },
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

  test("reconcileNow persists the reconciled store", async () => {
    const dir = mkdtempSync(join(tmpdir(), "saia-reconcile-"));
    try {
      const storePath = join(dir, "saia.json");
      const fakeFetch = (async (url: any) => {
        if (String(url).endsWith("/models")) {
          return new Response(
            JSON.stringify({
              object: "list",
              data: [{ id: "m-1", name: "M 1", input: ["text"], output: ["text"], status: "ready" }],
            }),
          );
        }
        if (String(url).endsWith("/chat/completions")) {
          return new Response('data: {"choices":[{"delta":{"content":"OK"}}]}\ndata: [DONE]');
        }
        return new Response("<html><table><tr><td>X</td><td>M 1</td><td>yes</td><td>2026</td><td>128K</td><td>-</td><td>-</td><td>-</td></tr></table></html>");
      }) as unknown as typeof fetch;
      const reconciler = createReconciler({
        config: { ...DEFAULT_CONFIG, storePath, probesPerCycle: 5, probeTimeoutMs: 100 },
        getApiKey: () => "key",
        fetchImpl: fakeFetch,
        logger: { warn: () => {} },
      });
      const summary = await reconciler.reconcileNow();
      expect(summary.modelsSeen).toBe(1);
      expect(summary.probesRun).toBe(1); // m-1 unknown -> probed
      const store = loadStore(storePath);
      expect(store.models["m-1"].reasoning).toBe(false); // probe got text-only stream
      expect(store.models["m-1"].contextWindow).toBe(128_000); // scraped by name "M 1" -> m-1
      expect(store.contextScrapedAt).toBeDefined();
      reconciler.stop();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("start defers and schedules interval; fresh store skips deferred cycle", async () => {
    const timeouts: Array<{ fn: () => void; ms: number }> = [];
    const intervals: Array<{ fn: () => void; ms: number }> = [];
    const fakeTimers = {
      setTimeout: ((fn: () => void, ms: number) => {
        timeouts.push({ fn, ms });
        return 1;
      }) as unknown as typeof setTimeout,
      clearTimeout: (() => {}) as unknown as typeof clearTimeout,
      setInterval: ((fn: () => void, ms: number) => {
        intervals.push({ fn, ms });
        return 2;
      }) as unknown as typeof setInterval,
      clearInterval: (() => {}) as unknown as typeof clearInterval,
    };
    // stale/missing store -> deferred cycle scheduled
    const staleDir = mkdtempSync(join(tmpdir(), "saia-stale-"));
    const stale = createReconciler({
      config: { ...DEFAULT_CONFIG, storePath: join(staleDir, "saia.json") },
      getApiKey: () => "key",
      logger: { warn: () => {} },
      ...fakeTimers,
    });
    stale.start();
    expect(timeouts).toHaveLength(1);
    rmSync(staleDir, { recursive: true, force: true });
    expect(timeouts[0].ms).toBe(DEFAULT_CONFIG.startupDelayMs);
    expect(intervals).toHaveLength(1);
    expect(intervals[0].ms).toBe(DEFAULT_CONFIG.intervalMs);
    stale.stop();

    // fresh store (recent updatedAt) -> no deferred cycle
    const freshDir = mkdtempSync(join(tmpdir(), "saia-fresh-"));
    try {
      const storePath = join(freshDir, "saia.json");
      saveStore(storePath, { version: 1, updatedAt: new Date().toISOString(), models: {} });
      const fresh = createReconciler({
        config: { ...DEFAULT_CONFIG, storePath },
        getApiKey: () => "key",
        logger: { warn: () => {} },
        ...fakeTimers,
      });
      fresh.start();
      expect(timeouts).toHaveLength(1); // unchanged: stale case scheduled 1
      expect(intervals).toHaveLength(2);
      fresh.stop();
    } finally {
      rmSync(freshDir, { recursive: true, force: true });
    }
  });
});
