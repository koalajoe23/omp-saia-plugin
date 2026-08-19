import { describe, expect, test, mock } from "bun:test";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import extensionFactory from "../extensions/index.js";
import { buildModelDefs, resolveContextWindow } from "../extensions/discovery.js";
import { toModelConfig } from "../extensions/config.js";
import type { SaiaModelResponse } from "../extensions/types.js";

const SAMPLE_RESPONSE: SaiaModelResponse = {
  object: "list",
  data: [
    {
      id: "glm-4.7",
      name: "GLM 4.7",
      input: ["text"],
      output: ["thought", "text"],
      status: "ready",
    },
    {
      id: "qwen3-30b-a3b-instruct-2507",
      name: "Qwen 3 30B A3B",
      input: ["text", "image"],
      output: ["text"],
      status: "ready",
    },
    {
      id: "unavailable-model",
      name: "Unavailable",
      input: ["text"],
      output: ["text"],
      status: "not_ready",
    },
  ],
};

describe("buildModelDefs", () => {
  test("filters out non-ready models", () => {
    const defs = buildModelDefs(SAMPLE_RESPONSE);
    expect(defs.map((d) => d.id)).toEqual(["glm-4.7", "qwen3-30b-a3b-instruct-2507"]);
  });

  test("detects reasoning from API output metadata and override set", () => {
    const defs = buildModelDefs(SAMPLE_RESPONSE);
    const glm = defs.find((d) => d.id === "glm-4.7")!;
    expect(glm.reasoning).toBe(true);
    // deepseek-v4-flash and gemma-4-31b-it are in the override set:
    // reasoning even without "thought" in output (verified against the live API)
    // Date-stamped variants (e.g. deepseek-v4-flash-0731) match via the base id.
    for (const id of ["deepseek-v4-flash", "gemma-4-31b-it", "deepseek-v4-flash-0731"]) {
      const override = buildModelDefs({
        object: "list",
        data: [{ id, name: id, input: ["text"], output: ["text"], status: "ready" }],
      })[0];
      expect(override.reasoning).toBe(true);
    }
  });

  test("detects vision from input modalities", () => {
    const defs = buildModelDefs(SAMPLE_RESPONSE);
    const qwen = defs.find((d) => d.id === "qwen3-30b-a3b-instruct-2507")!;
    expect(qwen.vision).toBe(true);
    expect(defs.find((d) => d.id === "glm-4.7")!.vision).toBe(false);
  });

  test("resolves context windows with default fallback", () => {
    expect(resolveContextWindow("glm-4.7")).toBe(200_000);
    expect(resolveContextWindow("unknown-model")).toBe(128_000);
    // date-stamped variant falls back to the base id's entry
    expect(resolveContextWindow("deepseek-v4-flash-0731")).toBe(1_000_000);
  });
});

describe("toModelConfig", () => {
  test("maps reasoning models to OMP thinking config", () => {
    const def = buildModelDefs(SAMPLE_RESPONSE)[0]; // glm-4.7, reasoning
    const config = toModelConfig(def);

    expect(config.reasoning).toBe(true);
    expect(config.thinking).toMatchObject({ mode: "effort" });
    expect([...(config.thinking?.efforts ?? [])] as unknown[]).toEqual([
      "minimal",
      "low",
      "medium",
      "high",
      "xhigh",
      "max",
    ]);
    expect(config.compat).toMatchObject({
      supportsDeveloperRole: false,
      supportsReasoningEffort: true,
    });
    expect(config.input).toEqual(["text"]);
  });

  test("maps non-reasoning vision models without thinking config", () => {
    const def = buildModelDefs(SAMPLE_RESPONSE)[1]; // qwen3-30b, vision, no reasoning
    const config = toModelConfig(def);

    expect(config.reasoning).toBe(false);
    expect(config.thinking).toBeUndefined();
    expect(config.compat).toEqual({ supportsDeveloperRole: false });
    expect(config.input).toEqual(["text", "image"]);
  });

  test("carries context window and token limits", () => {
    const def = buildModelDefs(SAMPLE_RESPONSE)[0];
    const config = toModelConfig(def);
    expect(config.contextWindow).toBe(200_000);
    expect(config.maxTokens).toBe(32_768);
    expect(config.cost).toEqual({ input: 0, output: 0, cacheRead: 0, cacheWrite: 0 });
  });
});

describe("extension factory", () => {
  interface Registration {
    name: string;
    config: Record<string, unknown>;
  }

  /** fetch stub matching Bun's fetch type (includes `preconnect`). */
  function stubFetch(response: SaiaModelResponse): typeof fetch {
    const stub = mock(() =>
      Promise.resolve(
        new Response(JSON.stringify(response), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      ),
    );
    return Object.assign(stub, { preconnect: mock(() => {}) }) as typeof fetch;
  }

  /** Minimal ExtensionAPI stand-in; only the surface the factory touches. */
  function fakePi(): { pi: ExtensionAPI; registrations: Registration[] } {
    const registrations: Registration[] = [];
    const pi = {
      logger: {
        info: mock(() => {}),
        warn: mock(() => {}),
        error: mock(() => {}),
        debug: mock(() => {}),
      },
      registerProvider: mock((name: string, config: Record<string, unknown>) => {
        registrations.push({ name, config });
      }),
    } as unknown as ExtensionAPI;
    return { pi, registrations };
  }

  test("registers the saia provider with dynamic discovery", () => {
    const { pi, registrations } = fakePi();

    extensionFactory(pi);

    expect(registrations).toHaveLength(1);
    const [registration] = registrations;
    expect(registration.name).toBe("saia");
    expect(registration.config.baseUrl).toBe("https://chat-ai.academiccloud.de/v1");
    expect(registration.config.api).toBe("openai-completions");
    expect(typeof registration.config.fetchDynamicModels).toBe("function");
  });

  test("stores the environment key as the config credential", () => {
    const { pi, registrations } = fakePi();
    const original = process.env.SAIA_API_KEY;
    process.env.SAIA_API_KEY = "test-key";
    try {
      extensionFactory(pi);
      expect(registrations[0].config.apiKey).toBe("test-key");
    } finally {
      if (original === undefined) delete process.env.SAIA_API_KEY;
      else process.env.SAIA_API_KEY = original;
    }
  });

  test("discovery callback maps the API response into model configs", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = stubFetch(SAMPLE_RESPONSE);
    try {
      const { pi, registrations } = fakePi();
      extensionFactory(pi);

      const config = registrations[0].config as { fetchDynamicModels: (k?: string) => Promise<unknown[]> };
      const models = await config.fetchDynamicModels("test-key");

      expect(models).toHaveLength(2);
      const glm = models[0] as { id: string; reasoning: boolean; contextWindow: number };
      expect(glm.id).toBe("glm-4.7");
      expect(glm.reasoning).toBe(true);
      expect(glm.contextWindow).toBe(200_000);
      const qwen = models[1] as { id: string; reasoning: boolean };
      expect(qwen.id).toBe("qwen3-30b-a3b-instruct-2507");
      expect(qwen.reasoning).toBe(false);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  test("registers without apiKey and returns no models when the key is missing", async () => {
    const { pi, registrations } = fakePi();
    const original = process.env.SAIA_API_KEY;
    delete process.env.SAIA_API_KEY;
    try {
      extensionFactory(pi);

      const [registration] = registrations;
      expect(registration.config.apiKey).toBeUndefined();

      const config = registration.config as { fetchDynamicModels: (k?: string) => Promise<unknown[]> };
      const models = await config.fetchDynamicModels(undefined);
      expect(models).toEqual([]);
    } finally {
      if (original !== undefined) process.env.SAIA_API_KEY = original;
    }
  });

  test("re-reads the environment key when discovery runs without a resolved key", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = stubFetch(SAMPLE_RESPONSE);
    try {
      const { pi, registrations } = fakePi();
      const original = process.env.SAIA_API_KEY;
      process.env.SAIA_API_KEY = "late-key";
      try {
        extensionFactory(pi);

        const config = registrations[0].config as { fetchDynamicModels: (k?: string) => Promise<unknown[]> };
        const models = await config.fetchDynamicModels(undefined);
        expect(models).toHaveLength(2);
      } finally {
        if (original === undefined) delete process.env.SAIA_API_KEY;
        else process.env.SAIA_API_KEY = original;
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
