import type { ProviderModelConfig } from "@oh-my-pi/pi-coding-agent";
import type { ModelDef } from "./types.js";
import { baseModelId } from "./discovery.js";

type ThinkingConfig = NonNullable<ProviderModelConfig["thinking"]>;

/**
 * OMP's Effort enum is nominal, but the wire values are plain strings equal
 * to the enum members' values. These arrays are cast at the boundary (see
 * REASONING_THINKING / EFFORT_LADDERS) — kept as string literals here to
 * avoid a runtime import of a transitive package subpath for the enum.
 */
const EFFORT_NAMES = ["minimal", "low", "medium", "high", "xhigh", "max"] as const;
type EffortName = (typeof EFFORT_NAMES)[number];

/**
 * Thinking capabilities for reasoning models.
 *
 * OMP's internal effort levels are `minimal | low | medium | high | xhigh |
 * max`. Most SAIA reasoning models are served by vLLM and accept exactly
 * those values for the standard OpenAI `reasoning_effort` parameter, so the
 * mapping is identity and no `effortMap` is needed. `mode: "effort"` makes
 * OMP send `reasoning_effort` when a thinking level is selected.
 *
 * Three models run non-vLLM gateways that accept only a subset of the ladder
 * (probed against the live API 2026-09-10); they get a restricted `efforts`
 * list and an `effortMap` where the wire value differs from the OMP level:
 *
 * - `mistral-medium-3.5-128b`: Mistral API accepts only `none`/`high` —
 *   OMP `minimal` is sent as wire `none`, all other levels are removed.
 * - `openai-gpt-oss-120b`: Harmony backend accepts only `low|medium|high`.
 * - `qwen3.8-27b`: accepts only `low|medium|xhigh`.
 */
/** OMP thinking config for SAIA reasoning models (efforts = vLLM's `reasoning_effort` values). */
const REASONING_THINKING: ThinkingConfig = {
  mode: "effort",
  // Cast is value-identical (see EFFORT_NAMES).
  efforts: EFFORT_NAMES as unknown as ThinkingConfig["efforts"],
};

/** Per-model effort restrictions, keyed on the base model id (date stamps stripped). */
const EFFORT_LADDERS: Record<string, ThinkingConfig> = {
  "mistral-medium-3.5-128b": {
    mode: "effort",
    efforts: ["minimal", "high"] as unknown as ThinkingConfig["efforts"],
    effortMap: { minimal: "none" },
  },
  "openai-gpt-oss-120b": {
    mode: "effort",
    efforts: ["low", "medium", "high"] as unknown as ThinkingConfig["efforts"],
  },
  "qwen3.8-27b": {
    mode: "effort",
    efforts: ["low", "medium", "xhigh"] as unknown as ThinkingConfig["efforts"],
  },
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
    thinking: def.reasoning ? (EFFORT_LADDERS[baseModelId(def.id)] ?? REASONING_THINKING) : undefined,
    compat: def.reasoning
      ? { ...BASE_COMPAT, ...REASONING_COMPAT }
      : BASE_COMPAT,
    input,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: def.contextWindow,
    maxTokens: def.maxTokens,
  };
}
