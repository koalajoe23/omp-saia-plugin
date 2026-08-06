export const PROVIDER_ID = "saia";
export const BASE_URL = "https://chat-ai.academiccloud.de/v1";
export const MODELS_ENDPOINT = `${BASE_URL}/models`;

export const DEFAULT_CONTEXT_WINDOW = 128_000;
export const DEFAULT_MAX_TOKENS = 32_768;

/** Context-window lookup from official SAIA docs (https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html). */
export const CONTEXT_WINDOWS: Record<string, number> = {
  "apertus-70b-instruct-2509": 65_536,
  "deepseek-v4-flash": 1_000_000,
  "devstral-2-123b-instruct-2512": 256_000,
  "gemma-4-31b-it": 256_000,
  "glm-4.7": 200_000,
  "meta-llama-3.1-8b-instruct": 128_000,
  "mistral-medium-3.5-128b": 256_000,
  "openai-gpt-oss-120b": 128_000,
  "qwen3-30b-a3b-instruct-2507": 256_000,
  "qwen3-coder-next": 256_000,
  "qwen3-omni-30b-a3b-instruct": 256_000,
  "qwen3.5-122b-a10b": 256_000,
  "qwen3.5-397b-a17b": 256_000,
  "qwen3.6-27b": 262_000,
  "qwen3.6-35b-a3b": 262_000,
  "medgemma-27b-it": 32_768,
};
