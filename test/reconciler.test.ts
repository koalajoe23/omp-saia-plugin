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
