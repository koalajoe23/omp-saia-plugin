import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import type { ModelDef } from "./types.js";

/**
 * Build a thinkingLevelMap for models that support reasoning via the SAIA API.
 *
 * The SAIA backend (vLLM) accepts standard OpenAI `reasoning_effort` with these values:
 *   none, minimal, low, medium, high, xhigh, max
 *
 * Pi's thinking levels map cleanly 1:1. `off` maps to "none" which tells vLLM
 * to skip the reasoning phase entirely.
 */
const REASONING_LEVEL_MAP: NonNullable<ProviderModelConfig["thinkingLevelMap"]> = {
  off: "none",
  minimal: "minimal",
  low: "low",
  medium: "medium",
  high: "high",
  xhigh: "xhigh",
  max: "max",
};

/**
 * Base compat settings for all SAIA models.
 *
 * - `supportsDeveloperRole: false` — vLLM rejects the `developer` role;
 *   pi falls back to `system` role messages.
 */
const BASE_COMPAT: NonNullable<ProviderModelConfig["compat"]> = {
  supportsDeveloperRole: false,
};

/**
 * Additional compat for reasoning-capable models.
 *
 * - `supportsThinkingTokenBudget: true` — enables vLLM's `thinking_token_budget`
 *   parameter so the reasoning phase cannot consume the entire token budget,
 *   leaving room for the final answer.
 */
const REASONING_COMPAT: NonNullable<ProviderModelConfig["compat"]> = {
  supportsThinkingTokenBudget: true,
};

/** Transform a resolved ModelDef into the ProviderModelConfig shape pi expects. */
export function toModelConfig(def: ModelDef): ProviderModelConfig {
  const input: ("text" | "image")[] = ["text"];
  if (def.vision) {
    input.push("image");
  }

  return {
    id: def.id,
    name: def.name,
    api: "openai-completions",
    reasoning: def.reasoning,
    thinkingLevelMap: def.reasoning ? REASONING_LEVEL_MAP : undefined,
    compat: def.reasoning
      ? { ...BASE_COMPAT, ...REASONING_COMPAT }
      : BASE_COMPAT,
    input,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: def.contextWindow,
    maxTokens: def.maxTokens,
  };
}
