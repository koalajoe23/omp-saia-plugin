import { MODELS_ENDPOINT, DEFAULT_CONTEXT_WINDOW, DEFAULT_MAX_TOKENS, CONTEXT_WINDOWS } from "./constants.js";
import type { SaiaModelResponse, ModelDef } from "./types.js";

/**
 * Models confirmed to support reasoning even though the SAIA API does not
 * include "thought" in their output array. The API metadata is incomplete
 * for certain vLLM-backed models that still accept `reasoning_effort` and
 * return `reasoning` content in responses.
 *
 * Verified by testing each model with `reasoning_effort: "high"` and
 * checking for a non-null `reasoning` field in the response.
 */
const REASONING_OVERRIDES: ReadonlySet<string> = new Set([
  "deepseek-v4-flash",
  "mistral-medium-3.5-128b",
  "openai-gpt-oss-120b",
  "qwen3.6-27b",
  "qwen3.6-35b-a3b",
]);

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

/**
 * Determine whether a model supports reasoning.
 *
 * The SAIA API includes "thought" in `output` for some reasoning models,
 * but many vLLM-backed models accept `reasoning_effort` and return
 * `reasoning` content without advertising it. We use a static override
 * set for models confirmed by direct testing.
 */
function supportsReasoning(entry: SaiaModelResponse["data"][number]): boolean {
  if (entry.output?.includes("thought")) return true;
  if (REASONING_OVERRIDES.has(entry.id)) return true;
  return false;
}

/** Build internal ModelDef array from the raw API response. */
export function buildModelDefs(response: SaiaModelResponse): ModelDef[] {
  return response.data
    .filter((entry) => entry.status === "ready")
    .map((entry) => ({
      id: entry.id,
      name: entry.name,
      reasoning: supportsReasoning(entry),
      vision: entry.input?.includes("image") ?? false,
      contextWindow: resolveContextWindow(entry.id),
      maxTokens: DEFAULT_MAX_TOKENS,
    }));
}
