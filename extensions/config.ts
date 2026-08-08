import type { ProviderModelConfig } from "@oh-my-pi/pi-coding-agent";
import type { ModelDef } from "./types.js";

/**
 * Thinking capabilities for reasoning models.
 *
 * OMP's internal effort levels are `minimal | low | medium | high | xhigh |
 * max`, and the SAIA backend (vLLM) accepts exactly those values for the
 * standard OpenAI `reasoning_effort` parameter — so the mapping is identity
 * and no `effortMap` is needed. `mode: "effort"` makes OMP send
 * `reasoning_effort` when a thinking level is selected.
 */
const REASONING_EFFORTS = ["minimal", "low", "medium", "high", "xhigh", "max"] as const;

type ThinkingConfig = NonNullable<ProviderModelConfig["thinking"]>;

/** OMP thinking config for SAIA reasoning models (efforts = vLLM's `reasoning_effort` values). */
const REASONING_THINKING: ThinkingConfig = {
  mode: "effort",
  // OMP's Effort enum is nominal, but the wire values are plain strings equal
  // to the enum members' values — the cast is value-identical. Kept local to
  // avoid a runtime import of a transitive package subpath.
  efforts: REASONING_EFFORTS as unknown as ThinkingConfig["efforts"],
};

/**
 * Base compat settings for all SAIA models.
 *
 * - `supportsDeveloperRole: false` — vLLM rejects the `developer` role;
 *   OMP falls back to `system` role messages.
 */
const BASE_COMPAT = {
  supportsDeveloperRole: false,
} as const;

/**
 * Additional compat for reasoning-capable models.
 *
 * - `supportsReasoningEffort: true` — the SAIA endpoint is not on OMP's
 *   URL auto-detection list, so without this flag `reasoning_effort` would
 *   be suppressed and thinking levels would have no effect.
 */
const REASONING_COMPAT = {
  supportsReasoningEffort: true,
} as const;

/** Transform a resolved ModelDef into the ProviderModelConfig shape OMP expects. */
export function toModelConfig(def: ModelDef): ProviderModelConfig {
  const input: ProviderModelConfig["input"] = ["text"];
  if (def.vision) {
    input.push("image");
  }

  return {
    id: def.id,
    name: def.name,
    reasoning: def.reasoning,
    thinking: def.reasoning ? REASONING_THINKING : undefined,
    compat: def.reasoning
      ? { ...BASE_COMPAT, ...REASONING_COMPAT }
      : BASE_COMPAT,
    input,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: def.contextWindow,
    maxTokens: def.maxTokens,
  };
}
