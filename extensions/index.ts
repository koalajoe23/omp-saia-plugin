/**
 * pi-saia-plugin: SAIA (Academic Cloud Hessen) provider registration.
 *
 * Registers the SAIA provider with GLM, Qwen, DevStral, and GPT-OSS models.
 * API key is read from auth.json (key: "saia") or models.json provider apiKey.
 *
 * Install: pi install /path/to/pi-saia-plugin
 * Reload:  /reload
 */

import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";

const SAIA_MODELS: ProviderModelConfig[] = [
  {
    id: "glm-4.7",
    name: "GLM 4.7 (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
  {
    id: "qwen3.5-397b-a17b",
    name: "Qwen 3.5 397B (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
  {
    id: "qwen3.5-122b-a10b",
    name: "Qwen 3.5 122B (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
  {
    id: "devstral-2-123b-instruct-2512",
    name: "DevStral 2 123B (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
  {
    id: "openai-gpt-oss-120b",
    name: "GPT-OSS 120B (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
  {
    id: "qwen3.6-27b",
    name: "Qwen 3.6 27B (SAIA)",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 131_072,
    maxTokens: 32_768,
  },
];

export default function (pi: ExtensionAPI) {
  pi.registerProvider("saia", {
    name: "SAIA Academic Cloud",
    baseUrl: "https://chat-ai.academiccloud.de/v1",
    apiKey: "$SAIA_API_KEY",
    api: "openai-completions",
    models: SAIA_MODELS,
  });
}
