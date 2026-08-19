---
name: saia-models
description: SAIA (Academic Cloud Hessen) provider models — reasoning, vision, context windows, and how to use them in OMP.
---

# SAIA Academic Cloud Models

This plugin registers the `saia` provider with OMP. Models are **dynamically discovered** from the SAIA API (`/v1/models`) through OMP's runtime discovery: results are cached for 24 h and refreshed at startup or on `omp models`.

## Model Capabilities

Capabilities (reasoning, vision) are detected from the API response:

| Capability | How detected |
|------------|-------------|
| **Reasoning** | API `output` contains `"thought"` |
| **Vision** | API `input` contains `"image"` |

### Models confirmed with reasoning support

Two detection methods are used (API metadata + direct testing):

**Detected via API (output includes `"thought"`):**

| Model ID | Name |
|----------|------|
| `saia/qwen3.5-122b-a10b` | Qwen 3.5 122B |
| `saia/qwen3.5-397b-a17b` | Qwen 3.5 397B |

**Detected via direct testing with `reasoning_effort`:**

| Model ID | Name |
|----------|------|
| `saia/deepseek-v4-flash` | DeepSeek V4 Flash |
| `saia/gemma-4-31b-it` | Gemma 4 31B |
| `saia/mistral-medium-3.5-128b` | Mistral Medium 3.5 |
| `saia/openai-gpt-oss-120b` | GPT-OSS 120B |
| `saia/qwen3.6-27b` | Qwen 3.6 27B |
| `saia/qwen3.6-35b-a3b` | Qwen 3.6 35B |

Date-stamped variants (e.g. `saia/deepseek-v4-flash-0731`) match the base id for capability lookups, so they inherit reasoning support and context window from the base model.

All reasoning models automatically get:

- `reasoning: true`
- `thinking: { mode: "effort", efforts: [minimal, low, medium, high, xhigh, max] }` — OMP thinking levels map 1:1 to the vLLM `reasoning_effort` values the SAIA backend accepts
- `compat.supportsReasoningEffort: true` so `reasoning_effort` is actually sent

All models get `compat.supportsDeveloperRole: false` (vLLM rejects the `developer` role; OMP falls back to `system`).

## Automatic updates

Capabilities reconcile automatically in the background (startup + every 6 h) and are stored in `~/.omp/agent/saia-models.json`; env vars `SAIA_RECONCILE_*` tune timing and location. Run `/saia-refresh` to reconcile immediately, then `omp models refresh` to surface the result.

## Usage

```bash
# List available SAIA models
omp models | grep ^saia

# Switch to a model
/model saia/qwen3.5-122b-a10b

# With thinking level
/model saia/qwen3.5-397b-a17b:high

# Force a refresh of the model list (bypass the 24 h cache)
omp models refresh | grep ^saia
```

## API Key

The API key is read from the `SAIA_API_KEY` environment variable (OMP loads `.env` files from the project, `~/.omp/agent/`, and `~/.omp/` too).

```bash
export SAIA_API_KEY=your-key
omp models | grep ^saia
```

Without a key the `saia` provider is registered but has no models; set the variable and run `omp models` to trigger discovery — no reload needed.
