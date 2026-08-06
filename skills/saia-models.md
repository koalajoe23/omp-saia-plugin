---
description: SAIA (Academic Cloud Hessen) models available via this plugin.
---

# SAIA Academic Cloud Models

This plugin registers the SAIA provider with models hosted on the Academic Cloud Hessen infrastructure. Models are **dynamically discovered** from the SAIA API on startup.

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
| `saia/mistral-medium-3.5-128b` | Mistral Medium 3.5 |
| `saia/openai-gpt-oss-120b` | GPT-OSS 120B |
| `saia/qwen3.6-27b` | Qwen 3.6 27B |
| `saia/qwen3.6-35b-a3b` | Qwen 3.6 35B |

All reasoning models automatically get:
- `reasoning: true`
- A `thinkingLevelMap` mapping pi's levels to vLLM `reasoning_effort` values (`none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`)
- `supportsThinkingTokenBudget: true` (vLLM's `thinking_token_budget` prevents thinking from consuming all tokens)

## Usage

```bash
# List available SAIA models
pi --list-models | grep ^saia

# Switch to a model
/model saia/qwen3.5-122b-a10b

# With thinking level
/model saia/qwen3.5-397b-a17b:high

# Set thinking as default for a session
/settings defaultThinkingLevel high
```

## API Key

The API key is resolved from `auth.json` (`saia` key), `models.json` provider config, or `$SAIA_API_KEY` environment variable.

Set it via:
```bash
/login saia
```

Or add to `auth.json`:
```json
{
  "saia": { "type": "api_key", "key": "your-key" }
}
```
