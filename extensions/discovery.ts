import { MODELS_ENDPOINT, DEFAULT_CONTEXT_WINDOW, DEFAULT_MAX_TOKENS, CONTEXT_WINDOWS } from "./constants.js";
import type { SaiaModelResponse, ModelDef } from "./types.js";

/**
 * Fetch available models from the SAIA API.
 * Requires SAIA_API_KEY environment variable.
 */
export async function fetchModels(): Promise<SaiaModelResponse> {
  const apiKey = process.env.SAIA_API_KEY;
  if (!apiKey) {
    throw new Error("SAIA_API_KEY environment variable not set");
  }

  const res = await fetch(MODELS_ENDPOINT, {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    signal: AbortSignal.timeout(15_000),
  });

  if (!res.ok) {
    throw new Error(`SAIA API returned ${res.status}: ${res.statusText}`);
  }

  return res.json() as Promise<SaiaModelResponse>;
}

/** Resolve context window for a model ID, falling back to the default. */
export function resolveContextWindow(modelId: string): number {
  return CONTEXT_WINDOWS[modelId] ?? DEFAULT_CONTEXT_WINDOW;
}

/** Build internal ModelDef array from the raw API response. */
export function buildModelDefs(response: SaiaModelResponse): ModelDef[] {
  return response.data
    .filter((entry) => entry.status === "ready")
    .map((entry) => ({
      id: entry.id,
      name: entry.name,
      reasoning: entry.output?.includes("thought") ?? false,
      vision: entry.input?.includes("image") ?? false,
      contextWindow: resolveContextWindow(entry.id),
      maxTokens: DEFAULT_MAX_TOKENS,
    }));
}
