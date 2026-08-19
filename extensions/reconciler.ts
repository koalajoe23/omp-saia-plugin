import { readFileSync, writeFileSync, renameSync, existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type { ModelStore } from "./types.js";

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
