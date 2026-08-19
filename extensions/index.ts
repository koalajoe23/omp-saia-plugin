/**
 * omp-saia-plugin: SAIA (Academic Cloud Hessen) provider registration for OMP.
 *
 * Registers the `saia` provider with OMP and discovers models dynamically
 * from the SAIA API `/v1/models` endpoint through OMP's standard runtime
 * discovery machinery (`fetchDynamicModels`): results are cached in OMP's
 * model-cache database (24 h TTL), refreshed at startup when uncached and on
 * `omp models` — no reload required when the model list changes.
 *
 * Capability reconciliation: a background reconciler (`reconciler.ts`) keeps
 * a persisted store of model capabilities (reasoning, vision, context
 * windows) fresh — deferred at startup, then on a timer while omp runs.
 * Discovery merges the store over the static tables, and `/saia-refresh`
 * triggers a reconcile on demand.
 *
 * API key: $SAIA_API_KEY environment variable (resolved at registration time
 * and stored as the provider's config-sourced credential; also re-read inside
 * the discovery callback so the key can appear after startup).
 *
 * Install: omp plugin link /path/to/omp-saia-plugin
 * Verify:  omp models | grep ^saia
 */

import type { ExtensionAPI, ExtensionCommandContext } from "@oh-my-pi/pi-coding-agent";
import { PROVIDER_ID, BASE_URL } from "./constants.js";
import { fetchModels, buildModelDefs } from "./discovery.js";
import { toModelConfig } from "./config.js";
import { parseConfig, createReconciler, loadStore } from "./reconciler.js";

export default function (pi: ExtensionAPI) {
  // Resolve the key now and register it as the config-sourced credential.
  // Only set when present: OMP treats a config `apiKey` as
  // env-var-name-or-literal, so passing the bare name with an unset variable
  // would send the literal string "SAIA_API_KEY" as the bearer token.
  const envKey = process.env.SAIA_API_KEY?.trim();
  const logger = pi.logger;
  const config = parseConfig(process.env as Record<string, string | undefined>);
  const reconciler = createReconciler({
    config,
    getApiKey: () => process.env.SAIA_API_KEY?.trim(),
    logger,
  });

  pi.registerProvider(PROVIDER_ID, {
    baseUrl: BASE_URL,
    api: "openai-completions",
    ...(envKey ? { apiKey: envKey } : {}),
    fetchDynamicModels: async (resolvedKey) => {
      // `resolvedKey` comes from OMP's credential resolution; fall back to
      // the environment so a key exported after startup still enables
      // discovery on the next refresh.
      const apiKey = resolvedKey ?? process.env.SAIA_API_KEY?.trim();
      if (!apiKey) {
        logger.warn(
          "[SAIA] No API key available; SAIA models are disabled. Set SAIA_API_KEY and run `omp models`.",
        );
        return [];
      }

      try {
        const response = await fetchModels(apiKey);
        const store = loadStore(config.storePath);
        const models = buildModelDefs(response, store).map(toModelConfig);
        logger.info(`[SAIA] Discovered ${models.length} models from API`);
        return models;
      } catch (error) {
        logger.warn("[SAIA] Failed to fetch models from API", {
          error: error instanceof Error ? error.message : String(error),
        });
        return [];
      }
    },
  });

  pi.registerCommand("saia-refresh", {
    description:
      "Reconcile SAIA model capabilities now (list, reasoning, vision, context windows)",
    handler: async (_args: string, ctx: ExtensionCommandContext) => {
      const summary = await reconciler.reconcileNow();
      const msg =
        `[SAIA] reconcile: ${summary.modelsSeen} models, ${summary.probesRun} probes, ` +
        `${summary.probeFailures} failures, scraped=${summary.scraped}. ` +
        `Run 'omp models refresh' to surface.`;
      ctx.ui.notify(msg, "info");
    },
  });

  reconciler.start();
}
