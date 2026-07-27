// Memory layer utilities for SAIA plugin
// Provides caching, usage tracking, metrics, and preferences for pi

import path from "node:path"
import os from "node:os"
import { platform } from "node:os"

const CACHE_DIR = path.join(os.homedir(), ".cache", "saia")
const CACHE_FILE = path.join(CACHE_DIR, "models.json")
const USAGE_FILE = path.join(CACHE_DIR, "pi-usage.jsonl")
const METRICS_FILE = path.join(CACHE_DIR, "pi-metrics.json")
const PREFERENCES_FILE = path.join(os.homedir(), ".config", "pi", "saia-preferences.json")
const PROJECT_CONTEXT_FILE = path.join(process.cwd(), ".pi", "saia", "context.json")

const CACHE_TTL_MS = 24 * 60 * 60 * 1000 // 24 hours
const MODELS_CACHE_FILE = path.join(CACHE_DIR, "pi-models-list.json")

/** Ensure cache directory exists */
export async function ensureCacheDir(): Promise<void> {
  try {
    const fs = await import("node:fs/promises")
    await fs.mkdir(CACHE_DIR, { recursive: true })
  } catch (err) {
    console.error(`[SAIA Memory] Failed to create cache directory: ${err}`)
  }
}

/**
 * Fetch with caching - returns cached data if valid, else fetches and caches
 */
export async function fetchWithCache<T>(
  fetcher: () => Promise<T>,
  forceRefresh = false,
): Promise<{ data: T; cached: boolean }> {
  await ensureCacheDir()

  // Check cache
  if (!forceRefresh) {
    try {
      const fs = await import("node:fs/promises")
      const cachedRaw = await fs.readFile(CACHE_FILE, "utf8")
      const cached = JSON.parse(cachedRaw) as { data: T; timestamp: number }
      const age = Date.now() - cached.timestamp
      if (age < CACHE_TTL_MS) {
        console.log(`[SAIA Memory] Cache hit (age: ${Math.round(age / 1000 / 60)}m)`)
        return { data: cached.data, cached: true }
      }
    } catch {
      // Cache miss or invalid
    }
  }

  // Fetch fresh data
  console.log("[SAIA Memory] Cache miss, fetching fresh data...")
  const data = await fetcher()

  // Update cache
  try {
    const fs = await import("node:fs/promises")
    const cacheEntry = { data, timestamp: Date.now() }
    const tmp = CACHE_FILE + ".tmp"
    await fs.writeFile(tmp, JSON.stringify(cacheEntry, null, 2))
    await fs.rename(tmp, CACHE_FILE)
    console.log("[SAIA Memory] Cache updated")
  } catch (err: unknown) {
    console.error(`[SAIA Memory] Failed to write cache: ${err instanceof Error ? err.message : String(err)}`)
  }

  return { data, cached: false }
}

/**
 * Clear all cache
 */
export async function clearCache(): Promise<void> {
  try {
    const fs = await import("node:fs/promises")
    await fs.unlink(CACHE_FILE).catch(() => {})
    await fs.unlink(MODELS_CACHE_FILE).catch(() => {})
    console.log("[SAIA Memory] Cache cleared")
  } catch (err) {
    console.error(`[SAIA Memory] Failed to clear cache: ${err}`)
  }
}

/**
 * Log model usage per project for pi
 */
export async function logUsage(modelId: string, taskType?: string, latencyMs?: number): Promise<void> {
  await ensureCacheDir()

  try {
    const fs = await import("node:fs/promises")
    const entry = {
      timestamp: new Date().toISOString(),
      projectRoot: process.cwd(),
      modelId,
      taskType: inferTaskType(taskType),
      latencyMs,
    }
    await fs.appendFile(USAGE_FILE, JSON.stringify(entry) + "\n")
  } catch (err: unknown) {
    console.error(`[SAIA Memory] Failed to log usage: ${err instanceof Error ? err.message : String(err)}`)
  }
}

/**
 * Update metrics for a model or API operation
 */
export async function updateMetrics(
  identifier: string,
  success: boolean,
  latencyMs?: number,
): Promise<void> {
  await ensureCacheDir()

  try {
    const fs = await import("node:fs/promises")
    const metricsRaw = await fs.readFile(METRICS_FILE, "utf8").catch(() => "{}")
    const metrics: Record<string, any> = JSON.parse(metricsRaw)

    if (!metrics[identifier]) {
      metrics[identifier] = { count: 0, success: 0, errors: 0, totalLatency: 0, lastUsed: null }
    }

    const entityMetrics = metrics[identifier] as Record<string, any>
    entityMetrics.count++
    entityMetrics[success ? "success" : "errors"]++
    if (latencyMs !== undefined) {
      entityMetrics.totalLatency += latencyMs
    }
    entityMetrics.lastUsed = new Date().toISOString()

    const tmp = METRICS_FILE + ".tmp"
    await fs.writeFile(tmp, JSON.stringify(metrics, null, 2))
    await fs.rename(tmp, METRICS_FILE)
  } catch (err: unknown) {
    console.error(`[SAIA Memory] Failed to update metrics: ${err instanceof Error ? err.message : String(err)}`)
  }
}

/**
 * Get user preferences for pi SAIA plugin
 */
export async function getPreferences(): Promise<Record<string, any>> {
  try {
    const fs = await import("node:fs/promises")
    const raw = await fs.readFile(PREFERENCES_FILE, "utf8")
    return JSON.parse(raw)
  } catch {
    return {}
  }
}

/**
 * Set user preferences for pi SAIA plugin
 */
export async function setPreferences(prefs: Record<string, unknown>): Promise<void> {
  try {
    const fs = await import("node:fs/promises")
    const existing = await getPreferences()
    const merged = { ...existing, ...prefs }
    const dir = path.dirname(PREFERENCES_FILE)
    await fs.mkdir(dir, { recursive: true })
    const tmp = PREFERENCES_FILE + ".tmp"
    await fs.writeFile(tmp, JSON.stringify(merged, null, 2))
    await fs.rename(tmp, PREFERENCES_FILE)
    console.log("[SAIA Memory] Preferences saved")
  } catch (err) {
    console.error(`[SAIA Memory] Failed to save preferences: ${err}`)
  }
}

/**
 * Get project context for pi
 */
export async function getContext(): Promise<Record<string, unknown>> {
  try {
    const fs = await import("node:fs/promises")
    const raw = await fs.readFile(PROJECT_CONTEXT_FILE, "utf8")
    return JSON.parse(raw)
  } catch {
    return {}
  }
}

/**
 * Update project context for pi
 */
export async function updateContext(updates: Record<string, unknown>): Promise<void> {
  try {
    const fs = await import("node:fs/promises")
    const existing = await getContext()
    const merged = { ...existing, ...updates }
    const dir = path.dirname(PROJECT_CONTEXT_FILE)
    await fs.mkdir(dir, { recursive: true })
    const tmp = PROJECT_CONTEXT_FILE + ".tmp"
    await fs.writeFile(tmp, JSON.stringify(merged, null, 2))
    await fs.rename(tmp, PROJECT_CONTEXT_FILE)
  } catch (err) {
    console.error(`[SAIA Memory] Failed to update project context: ${err}`)
  }
}

/**
 * Infer task type from file structure
 */
function inferTaskType(explicit?: string): string {
  if (explicit) return explicit

  const cwd = process.cwd()

  // Check for test files
  const files = ["test", "spec", ".test", ".spec"]
  if (files.some((f) => cwd.includes(f))) return "testing"

  // Check for docs
  const docFiles = ["README.md", "CHANGELOG.md", "docs/"]
  if (docFiles.some((f) => cwd.includes(f))) return "documentation"

  // Check for code
  const codeExtensions = [".ts", ".js", ".py", ".java", ".cpp", ".go", ".rs", ".php", ".rb"]
  if (codeExtensions.some((ext) => cwd.includes(ext))) return "coding"

  // Check for images
  const imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"]
  if (imageExtensions.some((ext) => cwd.includes(ext))) return "vision"

  return "general"
}

/**
 * Get recommended model based on usage and context
 */
export async function getRecommendedModel(availableModels: string[]): Promise<string> {
  const prefs = await getPreferences()
  const context = await getContext()

  if (prefs.favoriteModel) {
    return prefs.favoriteModel
  }

  if (context.preferredModel) {
    return context.preferredModel as string
  }

  // Fallback: pick glm-4.7 if available, else first model
  if (availableModels.includes("glm-4.7")) {
    return "glm-4.7"
  }

  return availableModels[0] || "unknown"
}

interface ModelDiff {
  added: string[]
  removed: string[]
}

/**
 * Check for new or removed models compared to the last cached list
 * Does NOT auto-refresh the cache — only detects changes for notification
 */
export async function checkForNewModels(
  apiBaseUrl = "https://chat-ai.academiccloud.de/v1",
  apiKey?: string,
): Promise<ModelDiff> {
  await ensureCacheDir()

  const fs = await import("node:fs/promises")

  // Read cached model list
  let cachedIds: string[] = []
  try {
    const raw = await fs.readFile(MODELS_CACHE_FILE, "utf8")
    const parsed = JSON.parse(raw)
    if (Array.isArray(parsed.ids)) {
      cachedIds = parsed.ids
    }
  } catch {
    // No cache yet — first run
  }

  // Fetch fresh model list
  const key = apiKey || process.env.SAIA_API_KEY || ""
  const url = `${apiBaseUrl.replace(/\/$/, "")}/models`

  let freshIds: string[] = []
  try {
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(15_000),
    })
    if (!res.ok) {
      console.error(`[SAIA Memory] checkForNewModels: API returned ${res.status}`)
      return { added: [], removed: [] }
    }
    const body: { data?: Array<{ id: string }> } = await res.json()
    freshIds = (body.data || []).map((m) => m.id).sort()

    // Persist the fresh list as the new cache snapshot
    const tmp = MODELS_CACHE_FILE + ".tmp"
    await fs.writeFile(tmp, JSON.stringify({ ids: freshIds, timestamp: Date.now() }, null, 2))
    await fs.rename(tmp, MODELS_CACHE_FILE)
  } catch (err) {
    console.error(`[SAIA Memory] checkForNewModels: fetch failed — ${err}`)
    return { added: [], removed: [] }
  }

  // No prior cache = first check, return empty diff
  if (cachedIds.length === 0) {
    return { added: [], removed: [] }
  }

  const cachedSet = new Set(cachedIds)
  const freshSet = new Set(freshIds)

  const added = freshIds.filter((id) => !cachedSet.has(id))
  const removed = cachedIds.filter((id) => !freshSet.has(id))

  if (added.length > 0 || removed.length > 0) {
    console.log(`[SAIA Memory] Model changes detected: +${added.length} -${removed.length}`)
    for (const id of added) {
      console.log(`  [+] ${id}`)
    }
    for (const id of removed) {
      console.log(`  [-] ${id}`)
    }
  }

  return { added, removed }
}

/**
 * Get usage statistics
 */
export async function getUsageStats(): Promise<Record<string, any>> {
  try {
    const fs = await import("node:fs/promises")
    const raw = await fs.readFile(USAGE_FILE, "utf8").catch(() => "")
    const lines = raw.trim().split("\n")
    
    const stats: Record<string, any> = {
      total: lines.length,
      byModel: {},
      byTask: {},
    }

    for (const line of lines) {
      if (!line.trim()) continue
      try {
        const entry = JSON.parse(line)
        const model = entry.modelId || "unknown"
        const task = entry.taskType || "unknown"

        stats.byModel[model] = (stats.byModel[model] || 0) + 1
        stats.byTask[task] = (stats.byTask[task] || 0) + 1
      } catch {
        // Skip invalid lines
      }
    }

    return stats
  } catch {
    return { total: 0, byModel: {}, byTask: {} }
  }
}

/**
 * Get metrics summary
 */
export async function getMetricsSummary(): Promise<Record<string, any>> {
  try {
    const fs = await import("node:fs/promises")
    const raw = await fs.readFile(METRICS_FILE, "utf8").catch(() => "{}")
    const metrics = JSON.parse(raw)

    const summary: Record<string, any> = {
      totalRequests: 0,
      successRate: 0,
      byEndpoint: {},
    }

    for (const [key, value] of Object.entries(metrics)) {
      const entry = value as Record<string, any>
      summary.totalRequests += entry.count || 0
      summary.byEndpoint[key] = {
        count: entry.count || 0,
        successRate: entry.count > 0 ? ((entry.success || 0) / entry.count) * 100 : 0,
        avgLatency: entry.count > 0 ? (entry.totalLatency || 0) / entry.count : 0,
      }
    }

    const successRates = Object.values(summary.byEndpoint).map((e: any) => e.successRate || 0)
    summary.successRate = summary.totalRequests > 0 && successRates.length > 0
      ? (successRates.reduce((sum, rate) => sum + rate, 0) / successRates.length)
      : 0

    return summary
  } catch {
    return { totalRequests: 0, successRate: 0, byEndpoint: {} }
  }
}
