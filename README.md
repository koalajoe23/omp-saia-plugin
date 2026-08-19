# omp-saia-plugin

> SAIA (Academic Cloud Hessen) provider for the [OMP coding agent](https://github.com/oh-my-pi/pi-coding-agent)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An [OMP plugin](https://github.com/oh-my-pi/pi-coding-agent) that auto-registers all **SAIA Academic Cloud** models as a provider — no manual configuration needed.

This is the OMP port of [pi-saia-plugin](https://github.com/tobias-weiss-ai-xr/pi-saia-plugin). It is part of a broader agent memory ecosystem; see the [agent-memory-research](https://github.com/tobias-weiss-ai-xr/agent-memory-research) survey [[arXiv 2512.13564](https://arxiv.org/abs/2512.13564)] for the research foundation driving our memory architecture design.

## Features

- **Dynamic discovery** — the provider is registered via OMP's runtime provider API (`pi.registerProvider()` with `fetchDynamicModels`); OMP queries the SAIA `/v1/models` endpoint through the same model-cache pipeline as built-in providers (24 h TTL, `omp models refresh` to force)
- **Zero config** — API key from `$SAIA_API_KEY` (OMP loads `.env` files automatically) or a config-sourced key; no reload needed once the key is set — `omp models` re-runs discovery
- **Skill included** — `/skill:saia-models` documents available models and usage
- **OpenAI-compatible** — uses standard `openai-completions` API (`chat-ai.academiccloud.de/v1`)

## Installation

```bash
# From a local checkout (recommended for development)
omp plugin link /path/to/omp-saia-plugin

# From git
omp plugin install github:koalajoe23/omp-saia-plugin
```

The plugin is enabled automatically on install. Restart omp if it was running.

## Available Models

Models are **dynamically discovered** from the SAIA API. The table below lists currently known models with context windows sourced from [official SAIA docs](https://docs.hpc.gwdg.de/services/ai-services/chat-ai/models/index.html).

| Model ID | Name | Context | Reasoning |
|----------|------|---------|-----------|
| `saia/apertus-70b-instruct-2509` | Apertus 70B | 65K | ❌ |
| `saia/glm-4.7` | GLM 4.7 | 200K | ❌ |
| `saia/qwen3.5-397b-a17b` | Qwen 3.5 397B | 256K | ✅ |
| `saia/qwen3.5-122b-a10b` | Qwen 3.5 122B | 256K | ✅ |
| `saia/devstral-2-123b-instruct-2512` | DevStral 2 123B | 256K | ❌ |
| `saia/openai-gpt-oss-120b` | GPT-OSS 120B | 128K | ✅ |
| `saia/qwen3.6-27b` | Qwen 3.6 27B | 262K | ✅ |
| `saia/qwen3.6-35b-a3b` | Qwen 3.6 35B | 262K | ✅ |
| `saia/deepseek-v4-flash-0731` | DeepSeek V4 Flash 0731 | 1M | ✅ |
| `saia/mistral-medium-3.5-128b` | Mistral Medium 3.5 | 256K | ✅ |
| `saia/gemma-4-31b-it` | Gemma 4 31B | 256K | ✅ |
| `saia/qwen3-30b-a3b-instruct-2507` | Qwen 3 30B | 256K | ❌ |
| `saia/qwen3-coder-next` | Qwen3 Coder Next | 256K | ❌ |
| `saia/qwen3-omni-30b-a3b-instruct` | Qwen3 Omni 30B | 256K | ❌ |
| `saia/meta-llama-3.1-8b-instruct` | Llama 3.1 8B | 128K | ❌ |
| `saia/medgemma-27b-it` | MedGemma 27B | 32K | ❌ |

> Reasoning status is verified against the live API (`reasoning_effort: "high"` probe, 2026-08-08); the ✅ set can change as SAIA updates model capabilities. The actual model set may vary — run `omp models | grep ^saia` to see what's currently available.

> **Date-stamped variants:** SAIA sometimes serves date-stamped variants of a model (e.g. `saia/deepseek-v4-flash-0731` alongside the base `deepseek-v4-flash`). Capability lookups strip a trailing `-NNNN` stamp, so variants inherit the base model's reasoning support and context window instead of falling back to defaults.

## Usage

```bash
# List available models
omp models | grep ^saia

# Switch to a model
/model saia/glm-4.7

# With thinking level
/model saia/qwen3.5-397b-a17b:high

# Force a refresh of the model list (bypass the 24 h cache)
omp models refresh

# Load the skill for documentation
/skill:saia-models
```

## Automatic capability reconciliation

The plugin keeps model capabilities (reasoning, vision, context windows) fresh in the background: a deferred cycle at startup (when the store is stale), then every 6 h while omp runs. Each cycle refreshes the model list, probes unknown models for reasoning (tiny ~2-token calls, ≤2 per cycle), re-scrapes SAIA's docs page weekly for context windows, and stores the result in `~/.omp/agent/saia-models.json`. omp picks the fresh data up at its next model discovery (`omp models` / `omp models refresh`).

Trigger a reconcile manually: `/saia-refresh` — then `omp models refresh` to surface the result immediately.

All timings are env-configurable (invalid values fall back to defaults):

| Variable | Default | Meaning |
|---|---|---|
| `SAIA_RECONCILE_STARTUP_DELAY_MS` | `5000` | defer reconcile after session start |
| `SAIA_RECONCILE_INTERVAL_MS` | `21600000` | background cycle (6 h) |
| `SAIA_RECONCILE_STALE_AFTER_MS` | `43200000` | catch-up at startup if store older |
| `SAIA_RECONCILE_PROBES_PER_CYCLE` | `2` | probe budget per cycle |
| `SAIA_RECONCILE_PROBE_TIMEOUT_MS` | `20000` | per-probe timeout |
| `SAIA_RECONCILE_REVERIFY_MS` | `604800000` | per-model re-verify (7 d) |
| `SAIA_RECONCILE_SCRAPE_INTERVAL_MS` | `604800000` | docs scrape cadence (7 d) |
| `SAIA_RECONCILE_SCRAPE_TIMEOUT_MS` | `15000` | scrape fetch timeout |
| `SAIA_RECONCILE_STORE_PATH` | `~/.omp/agent/saia-models.json` | store location |
| `SAIA_RECONCILE_DISABLED` | unset | set to any truthy value to disable |

Failures degrade silently to the last known state or the static tables; nothing blocks startup or discovery.

## API Key

The API key is resolved from `$SAIA_API_KEY` (OMP also loads `.env` files from the project, `~/.omp/agent/`, and `~/.omp/`):

```bash
export SAIA_API_KEY=your-key
omp models | grep ^saia
```

Without a key the `saia` provider is registered but carries no models; set the variable and run `omp models` to trigger discovery — no reload needed.

## Package Structure

```
omp-saia-plugin/
├── package.json              # OMP plugin manifest (omp.extensions)
├── extensions/
│   ├── index.ts              # Provider registration (pi.registerProvider + fetchDynamicModels)
│   ├── discovery.ts          # API client: fetchModels(), buildModelDefs()
│   ├── config.ts             # ModelDef → ProviderModelConfig transformer
│   ├── constants.ts          # Provider ID, base URL, context window table
│   └── types.ts              # TypeScript interfaces for API responses
├── skills/
│   └── saia-models/
│       └── SKILL.md          # Model documentation skill
└── test/
    └── extensions.test.ts    # bun test for discovery/config logic
```

## Development

```bash
git clone https://github.com/koalajoe23/omp-saia-plugin
cd omp-saia-plugin
bun install
bun check    # tsc --noEmit
bun test
```

Test locally:

```bash
omp plugin link /path/to/omp-saia-plugin
omp models | grep ^saia
```

## Porting Notes (pi → OMP)

| pi | OMP |
|----|-----|
| `pi.registerProvider(id, { models })` — one-shot fetch at startup | `pi.registerProvider(id, { fetchDynamicModels })` — OMP's runtime discovery pipeline (SQLite model cache, 24 h TTL, `omp models refresh`) |
| `thinkingLevelMap` (pi thinking levels → `reasoning_effort`) | `thinking: { mode: "effort", efforts: [...] }` — OMP levels map 1:1 to vLLM values; `compat.supportsReasoningEffort: true` |
| `compat.supportsThinkingTokenBudget` | not exposed by OMP's compat schema (dropped) |
| `apiKey: "$SAIA_API_KEY"` (deferred env resolution) | resolved at registration; env is re-read inside the discovery callback so the key can appear later |
| `pi install` / `/reload` | `omp plugin link` / `omp plugin install`; no reload needed for model changes |

## Acknowledgements

This plugin is based on [pi-saia-plugin](https://github.com/tobias-weiss-ai-xr/pi-saia-plugin) by [Tobias Weiss](https://github.com/tobias-weiss-ai-xr): the model discovery logic, context-window tables, reasoning verification data, and skill content are derived from that project, ported from the pi extension API to OMP's. Thanks to the original author and contributors.

## License

MIT
