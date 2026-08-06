import type { ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import type { ModelDef } from "./types.js";

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
    input,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: def.contextWindow,
    maxTokens: def.maxTokens,
  };
}
