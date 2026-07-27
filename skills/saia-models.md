---
description: SAIA (Academic Cloud Hessen) models available via this plugin.
---

# SAIA Academic Cloud Models

This plugin registers the SAIA provider with 6 models hosted on the Academic Cloud Hessen infrastructure.

## Available Models

| Model ID | Name | Context | Reasoning |
|----------|------|---------|-----------|
| `saia/glm-4.7` | GLM 4.7 | 128K | ✅ |
| `saia/qwen3.5-397b-a17b` | Qwen 3.5 397B | 128K | ✅ |
| `saia/qwen3.5-122b-a10b` | Qwen 3.5 122B | 128K | ✅ |
| `saia/devstral-2-123b-instruct-2512` | DevStral 2 123B | 128K | ✅ |
| `saia/openai-gpt-oss-120b` | GPT-OSS 120B | 128K | ✅ |
| `saia/qwen3.6-27b` | Qwen 3.6 27B | 128K | ✅ |

## Usage

```bash
# Switch to a SAIA model
/model saia/glm-4.7

# Or with thinking level
/model saia/qwen3.5-397b-a17b:high

# Switch to a lightweight model for quick tasks
/model saia/qwen3.6-27b
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
