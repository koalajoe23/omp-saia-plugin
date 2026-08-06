/**
 * pi-saia-plugin: SAIA (Academic Cloud Hessen) provider registration.
 *
 * Discovers models dynamically from the SAIA API /models endpoint
 * at startup, resolves capabilities from the response, and registers
 * the provider with pi.
 *
 * API key: $SAIA_API_KEY environment variable (or via /login saia)
 *
 * Install: pi install /path/to/pi-saia-plugin
 * Reload:  /reload
 */

import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { PROVIDER_ID, BASE_URL } from "./constants.js";
import { fetchModels, buildModelDefs } from "./discovery.js";
import { toModelConfig } from "./config.js";

export default async function (pi: ExtensionAPI) {
  let models: ProviderModelConfig[] = [];

  try {
    const response = await fetchModels();
    const defs = buildModelDefs(response);
    models = defs.map(toModelConfig);
    console.log(`[SAIA] Discovered ${models.length} models from API`);
  } catch (error) {
    console.warn(
      "[SAIA] Failed to fetch models from API:",
      error instanceof Error ? error.message : error,
    );
    console.warn("[SAIA] Registering provider with no models. Set $SAIA_API_KEY and reload.");
  }

  pi.registerProvider(PROVIDER_ID, {
    name: "SAIA Academic Cloud",
    baseUrl: BASE_URL,
    apiKey: "$SAIA_API_KEY",
    models,
  });
}
