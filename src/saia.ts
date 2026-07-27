// pi SAIA Plugin
// Drop this file into ~/.config/pi/plugins/saia.ts
// and add "saia" to your pi config plugins array

import path from "node:path"
import os from "node:os"
import fs from "node:fs/promises"

import * as memory from "./saia-memory.js"

// Configuration paths
const CONFIG = path.join(os.homedir(), ".config", "pi", "pi.json")
const PLUGIN_DIR = path.join(os.homedir(), ".config", "pi", "plugins", "saia")
const PLUGIN_CONFIG = path.join(PLUGIN_DIR, "pi-saia.json")
const MODEL_CACHE = path.join(PLUGIN_DIR, "models.json")

// API configuration
const DEFAULT_ENDPOINT = "https://chat-ai.academiccloud.de/v1/models"
const SAIA_API_KEY = process.env.SAIA_API_KEY || process.env.PI_SAIA_API_KEY

// Default permissions for SAIA plugin
export const PERMISSIONS: Record<string, "allow" | "ask" | "deny"> = {
  bash: "allow",
  edit: "allow",
  read: "allow",
  grep: "allow",
  glob: "allow",
  lsp: "allow",
  skill: "allow",
  task: "allow",
  webfetch: "allow",
  websearch: "allow",
  question: "allow",
  external_directory: "ask",
  doom_loop: "ask",
}

/**
 * Main plugin entry point
 * Called by pi when loading the plugin
 */
export default async (pi: any) => {
  // Register the plugin
  const pluginName = "saia"

  // Ensure plugin directory exists
  const pluginDir = path.join(os.homedir(), ".config", "pi", "plugins", pluginName)
  await fs.mkdir(pluginDir, { recursive: true }).catch(() => {})

  // Refresh SAIA config on startup
  refreshSaiaConfig(pi).catch((err) => {
    console.error("[SAIA Plugin] Initialization error:", err)
  })

  // Register commands
  if (pi.registerCommand) {
    // Refresh models
    pi.registerCommand("refresh-saia-models", {
      description: "Manually refresh SAIA model list from API",
      handler: async () => {
        await refreshSaiaConfig(pi, true)
        console.log("SAIA models refreshed successfully")
      },
    })

    // List models
    pi.registerCommand("list-saia-models", {
      description: "List all available SAIA models",
      handler: async () => {
        const list = await listModels()
        console.log(list)
      },
    })

    // Switch profile
    pi.registerCommand("saia-set-profile", {
      description: "Switch SAIA profile (production, development, budget)",
      handler: async (args: string) => {
        const profile = args.trim()
        if (!["production", "development", "dev", "budget"].includes(profile)) {
          console.log(`Invalid profile: ${profile}. Valid: production, development, dev, budget`)
          return
        }
        process.env.SAIA_PROFILE = profile
        await refreshSaiaConfig(pi, true)
        await memory.setPreferences({ defaultProfile: profile })
        console.log(`Switched to ${profile} profile and refreshed models`)
      },
    })

    // Get usage stats
    pi.registerCommand("saia-usage", {
      description: "Show SAIA usage statistics",
      handler: async () => {
        const stats = await memory.getUsageStats()
        console.log(JSON.stringify(stats, null, 2))
      },
    })
  }

  // Skills are loaded automatically by pi from ./skills/ (declared in package.json)
  // Legacy .opencode/skills/ files are not registered here; registerSkill is not part of ExtensionAPI

  console.log(`[SAIA Plugin] Loaded successfully`)

  return {
    name: pluginName,
    permissions: PERMISSIONS,
    config: {
      provider: "saia",
      description: "SAIA (GWDG Chat AI) integration for pi",
    },
  }
}

/**
 * List all available models with metadata
 */
async function listModels(): Promise<string> {
  try {
    const { data } = await memory.fetchWithCache(fetchModels)
    const modelIds = data.data.map((m) => m.id).sort()
    
    const filteredModels = modelIds.filter((id) => includeInProfile(id, process.env.SAIA_PROFILE || "production"))
    
    if (filteredModels.length === 0) return "No models available"
    
    let output = `**Available SAIA Models (${filteredModels.length} total):**\n\n`
    
    // Group by category
    const categories: Record<string, string[]> = {}
    for (const id of filteredModels) {
      const cat = categorizeModel(id)
      if (!categories[cat]) categories[cat] = []
      categories[cat].push(id)
    }
    
    for (const [category, models] of Object.entries(categories)) {
      output += `### ${category.charAt(0).toUpperCase() + category.slice(1)}\n`
      for (const model of models) {
        const metadata = getModelMetadata(model)
        const reason = metadata.can_reason ? " [reasoning]" : ""
        const attach = metadata.attachment ? " [vision]" : ""
        output += `- \`${model}\`${reason}${attach}\n`
      }
      output += "\n"
    }
    
    output += "**Aliases:**\n"
    const aliases = [
      "best-for-coding",
      "best-for-reasoning",
      "best-for-vision",
      "best-for-agentic",
      "best-quality",
      "fastest",
      "budget",
      "best-german",
    ]
    for (const alias of aliases) {
      output += `- \`${alias}\`\n`
    }
    
    return output
  } catch (err) {
    return `Error listing models: ${err}`
  }
}

/**
 * Fetch models from SAIA API
 */
async function fetchModels(endpoint?: string): Promise<{ data: Array<{ id: string }> }> {
  const apiKey = process.env.SAIA_API_KEY || SAIA_API_KEY
  if (!apiKey) {
    throw new Error("SAIA_API_KEY environment variable not set")
  }

  const url = endpoint || DEFAULT_ENDPOINT

  const startTime = Date.now()
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${apiKey}` },
    signal: AbortSignal.timeout(30000), // 30 seconds timeout
  })
  const latencyMs = Date.now() - startTime

  if (!res.ok) {
    await memory.updateMetrics("api", false, latencyMs)
    throw new Error(`SAIA API returned ${res.status}: ${res.statusText}`)
  }

  await memory.updateMetrics("api", true, latencyMs)
  const json = (await res.json()) as unknown as { data: Array<{ id: string }> }
  return json
}

/**
 * Generate model metadata for a given model ID
 */
function getModelMetadata(modelId: string): Record<string, any> {
  const metadata: Record<string, any> = {
    name: modelId,
    id: modelId,
  }

  // Categorization
  const category = categorizeModel(modelId)
  if (category) {
    metadata.category = category
  }

  // Descriptions
  const description = getModelDescription(modelId)
  if (description) {
    metadata.description = description
  }

  // Model capabilities
  if (canReason(modelId)) {
    metadata.can_reason = true
  }

  if (supportsAttachment(modelId)) {
    metadata.attachment = true
  }

  // Limits
  metadata.limit = {
    context: getContextWindow(modelId),
    output: getOutputWindow(modelId),
  }

  // Additional metadata
  metadata.metadata = {
    cost_per_1k_tokens: getCostPer1kTokens(modelId),
    estimated_latency: getEstimatedLatency(modelId),
    recommended_for: getRecommendedFor(modelId),
  }

  return metadata
}

/**
 * Categorize model based on ID
 */
function categorizeModel(modelId: string): string {
  const id = modelId.toLowerCase()
  if (id.includes("thinking") || id.includes("r1") || id.includes("deepseek")) {
    return "reasoning"
  }
  if (id.includes("coder")) {
    return "coder"
  }
  if (id.includes("vl") || id.includes("vision") || id.includes("internvl")) {
    return "vision"
  }
  if (id.includes("med") || id.includes("medical")) {
    return "medical"
  }
  if (id.includes("teuken") || id.includes("sauerkraut")) {
    return "research"
  }
  if (id.includes("glm-4.7") || id.includes("devstral") || id.includes("agent")) {
    return "agentic"
  }
  if (id.includes("235b") || id.includes("675b") || id.includes("120b")) {
    return "large-context"
  }
  return "general"
}

/**
 * Get human-readable description for a model
 */
function getModelDescription(modelId: string): string | null {
  const descriptions: Record<string, string> = {
    "qwen3.5-397b-a17b": "Qwen3.5 397B MoE (128k ctx) — Flagship reasoning, best quality",
    "qwen3.5-122b-a10b": "Qwen3.5 122B MoE (128k ctx) — Strong reasoning, fast",
    "qwen3.5-35b-a3b": "Qwen3.5 35B MoE (128k ctx) — Fast reasoning",
    "qwen3.5-27b": "Qwen3.5 27B Dense (128k ctx) — Efficient reasoning",
    "qwen3.6-35b-a3b": "Qwen3.6 35B MoE — Vision, reasoning, agentic coding",
    "qwen3-235b-a22b": "Qwen3 235B MoE (128k ctx) — Large context, strong generalist",
    "qwen3-32b": "Qwen3 32B Dense (128k ctx) — Balanced",
    "qwen3-coder-30b-a3b-instruct": "Qwen3 Coder 30B — Code-specialized",
    "qwen3-omni-30b-a3b-instruct": "Qwen3 Omni 30B — Multimodal (text+audio)",
    "qwen3-vl-30b-a3b-instruct": "Qwen3 VL 30B — Vision-language",
    "qwen3-30b-a3b-thinking-2507": "Qwen3 30B Thinking — Chain-of-thought reasoning",
    "qwen3-30b-a3b-instruct-2507": "Qwen3 30B Instruct — General purpose",
    "mistral-large-3-675b-instruct-2512": "Mistral Large 3 675B (128k ctx) — Largest model, strong generalist",
    "openai-gpt-oss-120b": "OpenAI GPT-OSS 120B — Large context model",
    "devstral-2-123b-instruct-2512": "Devstral 2 123B — Mistral's agentic coder",
    "glm-4.7": "GLM-4.7 (128k ctx) — Agentic coding, strong tool use",
    "deepseek-r1-distill-llama-70b": "DeepSeek R1 Distill 70B — Reasoning (Llama base)",
    "gemma-3-27b-it": "Gemma 3 27B — Google lightweight model",
    "gemma-4-31b-it": "Gemma 4 31B — Google latest",
    "llama-3.3-70b-instruct": "Llama 3.3 70B — Meta strong generalist",
    "llama-3.1-8b-instruct": "Llama 3.1 8B — Meta fast lightweight",
    "apertus-70b-instruct-2509": "Apertus 70B — Open-source instruct model",
    "internvl3.5-30b-a3b": "InternVL 3.5 30B — Vision-language",
    "medgemma-27b-it": "MedGemma 27B — Medical domain specialist",
    "teuken-7b-instruct-research": "Teuken 7B — German research model",
    "llama-3.1-sauerkrautlm-70b-instruct": "SauerkrautLM 70B — German-enhanced Llama",
    "meta-llama-3.1-8b-instruct": "Llama 3.1 8B — Meta lightweight",
  }

  return descriptions[modelId] || null
}

/**
 * Check if model supports reasoning
 */
function canReason(modelId: string): boolean {
  const reasoningModels = [
    "thinking",
    "r1",
    "deepseek",
    "qwen3.5-397b-a17b",
    "qwen3.5-122b-a10b",
    "qwen3.5-35b-a3b",
    "qwen3.5-27b",
    "qwen3.6-35b-a3b",
    "glm-4.7",
    "qwen3-235b-a22b",
    "qwen3-30b-a3b-instruct-2507",
  ]
  return reasoningModels.some((m) => modelId.toLowerCase().includes(m))
}

/**
 * Check if model supports attachments (vision)
 */
function supportsAttachment(modelId: string): boolean {
  const visionModels = [
    "qwen3-vl-30b-a3b-instruct",
    "internvl3.5-30b-a3b",
    "qwen3.6-35b-a3b",
    "qwen3-omni-30b-a3b-instruct",
  ]
  return visionModels.includes(modelId.toLowerCase())
}

/**
 * Get context window for model
 */
function getContextWindow(modelId: string): number {
  const largeModels = [
    "qwen3.5-397b-a17b",
    "qwen3.5-122b-a10b",
    "qwen3.5-35b-a3b",
    "qwen3.5-27b",
    "qwen3.6-35b-a3b",
    "qwen3-235b-a22b",
    "qwen3-32b",
    "mistral-large-3-675b-instruct-2512",
    "glm-4.7",
    "llama-3.3-70b-instruct",
    "llama-3.1-8b-instruct",
    "llama-3.1-sauerkrautlm-70b-instruct",
    "meta-llama-3.1-8b-instruct",
    "apertus-70b-instruct-2509",
    "devstral-2-123b-instruct-2512",
    "openai-gpt-oss-120b",
    "deepseek-r1-distill-llama-70b",
  ]
  if (largeModels.some((m) => modelId.toLowerCase().includes(m))) {
    return 128000
  }

  const mediumModels = [
    "gemma-3-27b-it",
    "gemma-4-31b-it",
    "qwen3-coder-30b-a3b-instruct",
    "qwen3-30b-a3b-instruct-2507",
    "qwen3-30b-a3b-thinking-2507",
  ]
  if (mediumModels.some((m) => modelId.toLowerCase().includes(m))) {
    return 131072
  }

  return 32768
}

/**
 * Get output window for model
 */
function getOutputWindow(modelId: string): number {
  const id = modelId.toLowerCase()
  if (id.includes("397b-a17b") || id.includes("122b-a10b") || id.includes("35b-a3b") || id.includes("qwen3.6-35b") || id.includes("mistral-large-3") || id.includes("235b-a22b")) {
    return 32768
  }
  if (id.includes("30b-instruct-2507") || id.includes("30b-thinking-2507") || id.includes("glm-4.7") || id.includes("devstral-2") || id.includes("qwen3-32b") || id.includes("coder-30b") || id.includes("deepseek")) {
    return 16384
  }
  if (id.includes("gemma-3") || id.includes("gemma-4") || id.includes("llama-3.3") || id.includes("apertus") || id.includes("gpt-oss")) {
    return 8192
  }
  if (id.includes("vl-") || id.includes("vision") || id.includes("internvl") || id.includes("medgemma") || id.includes("omni") || id.includes("teuken") || id.includes("sauerkraut") || id.includes("meta-llama-3.1")) {
    return 4096
  }
  return 8192
}

/**
 * Get estimated cost per 1k tokens
 */
function getCostPer1kTokens(modelId: string): number {
  const id = modelId.toLowerCase()
  if (id.includes("8b")) return 0.003
  if (id.includes("7b") || id.includes("gemma-3-27b")) return 0.006
  if (id.includes("31b") || id.includes("32b") || id.includes("teuken")) return 0.012
  if (id.includes("35b-a3b") || id.includes("30b")) return 0.018
  if (id.includes("70b")) return 0.025
  if (id.includes("122b")) return 0.038
  if (id.includes("235b") || id.includes("mistral-large")) return 0.075
  if (id.includes("397b") || id.includes("675b")) return 0.125
  return 0.015
}

/**
 * Get estimated latency category
 */
function getEstimatedLatency(modelId: string): string {
  const id = modelId.toLowerCase()
  if (id.includes("8b") || id.includes("7b") || id.includes("gemma")) return "fast"
  if (id.includes("27b") || id.includes("teuken") || id.includes("apertus")) return "moderate"
  if (id.includes("31b") || id.includes("32b")) return "moderate"
  if (id.includes("35b-a3b") || id.includes("30b")) return "moderate"
  if (id.includes("qwen3.5-122b")) return "slow"
  if (id.includes("coder") || id.includes("glm-4.7")) return "fast"
  if (id.includes("deepseek") || id.includes("70b") || id.includes("r1")) return "slow"
  if (id.includes("235b") || id.includes("mistral-large")) return "slow"
  if (id.includes("397b") || id.includes("675b")) return "very-slow"
  return "moderate"
}

/**
 * Get recommended use cases for model
 */
function getRecommendedFor(modelId: string): string[] {
  const id = modelId.toLowerCase()
  if (id.includes("coder")) return ["agentic-coding", "code-refactor", "debug"]
  if (id.includes("vision") || id.includes("vl-") || id.includes("internvl")) return ["image-analysis", "multimodal", "diagrams"]
  if (id.includes("thinking") || id.includes("r1") || id.includes("deepseek")) return ["complex-reasoning", "math", "planning"]
  if (id.includes("glm-4.7") || id.includes("devstral")) return ["agentic-coding", "tool-use", "architecture"]
  if (id.includes("med")) return ["medical-qa", "healthcare", "biomedical"]
  if (id.includes("teuken") || id.includes("sauerkraut")) return ["german-text", "research", "academic"]
  if (id.includes("397b")) return ["complex-reasoning", "high-quality-writing"]
  if (id.includes("122b")) return ["balanced-response", "fast-reasoning"]
  if (id.includes("35b")) return ["fast-reasoning", "general-purpose"]
  if (id.includes("27b")) return ["efficient-reasoning", "cost-optimization"]
  if (id.includes("8b")) return ["quick-edits", "summarization", "cost-optimization"]
  if (id.includes("70b") || id.includes("675b")) return ["large-context", "document-analysis", "complex-tasks"]
  if (id.includes("235b")) return ["large-batch", "context-heavy", "multiple-files"]
  return ["general-purpose", "chat", "daily-tasks"]
}

/**
 * Check if model should be included in selected profile
 */
function includeInProfile(modelId: string, profile: string): boolean {
  const id = modelId.toLowerCase()

  switch (profile) {
    case "production":
      return [
        "qwen3.5-397b-a17b",
        "qwen3.5-122b-a10b",
        "qwen3-235b-a22b",
        "mistral-large-3-675b",
        "glm-4.7",
        "devstral-2",
        "deepseek-r1",
        "coder",
        "qwen3-vl",
        "internvl",
      ].some((m) => id.includes(m))

    case "development":
    case "dev":
      return [
        "qwen3.5-35b-a3b",
        "qwen3.5-27b",
        "qwen3-32b",
        "llama-3.3-70b",
        "gemma-3-27b",
        "gemma-4-31b",
        "qwen3-coder",
        "glm-4.7",
        "vl-",
        "vision",
        "internvl",
      ].some((m) => id.includes(m))

    case "budget":
      return [
        "llama-3.1-8b",
        "teuken-7b",
        "qwen3-30b-a3b-instruct",
        "gemma-3-27b",
      ].some((m) => id.includes(m))

    default:
      return true
  }
}

/**
 * Get default model for profile
 */
function getProfileDefaultModel(profile: string): string {
  switch (profile) {
    case "production":
      return "glm-4.7"
    case "development":
    case "dev":
      return "qwen3.5-35b-a3b"
    case "budget":
      return "llama-3.1-8b-instruct"
    default:
      return "glm-4.7"
  }
}

/**
 * Refresh SAIA configuration
 */
async function refreshSaiaConfig(pi: any, forceRefresh = false) {
  const profile = process.env.SAIA_PROFILE || "production"
  const startTime = Date.now()

  // Check for LiteLLM proxy — pass custom endpoint to fetchModels if set
  const apiEndpoint = process.env.LITELLM_PROXY_URL || undefined

  let result
  try {
    result = await memory.fetchWithCache(() => fetchModels(apiEndpoint), forceRefresh)
    await memory.updateMetrics("refresh", true, Date.now() - startTime)
  } catch (err) {
    await memory.updateMetrics("refresh", false, Date.now() - startTime)
    console.error("[SAIA] Config refresh failed:", err instanceof Error ? err.message : err)
    return
  }

  if (result.cached) {
    console.log("[SAIA] Using cached model list")
  }

  const { data } = result.data
  const modelIds = data.map((m) => m.id).sort()

  if (modelIds.length === 0) {
    console.warn("[SAIA] No models available from API")
    return
  }

  // Filter models based on profile
  const profileModels = modelIds.filter((id) => includeInProfile(id, profile))

  // Generate plugin config
  const pluginConfig: Record<string, any> = {
    $schema: "https://pi.code/config.json",
    permission: { ...PERMISSIONS },
    provider: {
      saia: {
        npm: "@ai-sdk/openai-compatible",
        name: "SAIA (GWDG Chat AI)",
        options: {
          baseURL: "https://chat-ai.academiccloud.de/v1",
          apiKey: "{env:SAIA_API_KEY}",
        },
        models: {},
      },
    },
  }

  // Add models to config
  for (const modelId of profileModels) {
    const metadata = getModelMetadata(modelId)
    // Remove the 'id' field as it's redundant with the key
    delete metadata.id

    pluginConfig.provider.saia.models[modelId] = metadata
  }

  // Add model aliases
  const aliases = {
    "best-for-coding": "qwen3-coder-30b-a3b-instruct",
    "best-for-reasoning": "deepseek-r1-distill-llama-70b",
    "best-for-vision": "internvl3.5-30b-a3b",
    "best-for-agentic": "glm-4.7",
    "best-quality": "qwen3.5-397b-a17b",
    "fastest": "llama-3.1-8b-instruct",
    "budget": "llama-3.1-8b-instruct",
    "best-german": "llama-3.1-sauerkrautlm-70b-instruct",
  }

  for (const [aliasName, aliasTarget] of Object.entries(aliases)) {
    if (profileModels.includes(aliasTarget)) {
      pluginConfig.provider.saia.models[aliasName] = {
        name: `Alias for ${aliasTarget}`,
        alias: true,
        options: {
          "enable-tools": true,
          "enable-auto-tool-choice": true,
          "tool-call-parser": "openai",
        },
      }
    }
  }

  // Set default model
  const defaultModel = getProfileDefaultModel(profile)
  if (profileModels.includes(defaultModel)) {
    pluginConfig.model = `saia/${defaultModel}`
  } else if (profileModels.length > 0) {
    pluginConfig.model = `saia/${profileModels[0]}`
  }

  // Add timestamp
  pluginConfig.last_updated = new Date().toISOString()

  // Write plugin config
  const tmp = PLUGIN_CONFIG + ".tmp"
  await fs.writeFile(tmp, JSON.stringify(pluginConfig, null, 2))
  await fs.rename(tmp, PLUGIN_CONFIG)

  console.log(`[SAIA] Config refreshed: ${profileModels.length} models (${result.cached ? "from cache" : "fresh"})`)
  console.log(`[SAIA] Default model: ${pluginConfig.model}`)
  console.log(`[SAIA] Plugin config: ${PLUGIN_CONFIG}`)

  // Log to pi if available
  if (pi?.log) {
    try {
      await pi.log({
        level: "info",
        message: `SAIA plugin: refreshed ${profileModels.length} models`,
        data: { cached: result.cached, profile, modelCount: profileModels.length },
      })
    } catch {
      // Ignore logging errors
    }
  }
}
