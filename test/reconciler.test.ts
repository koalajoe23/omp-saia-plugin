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
