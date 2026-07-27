# pi-saia-plugin

> SAIA (Academic Cloud Hessen) provider for the [pi coding agent](https://pi.dev)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Pi Package](https://img.shields.io/badge/pi-package-blue)](https://pi.dev/packages)

A [pi package](https://pi.dev/docs/packages) that auto-registers all **SAIA Academic Cloud** models as a provider — no manual configuration needed.

This plugin is part of a broader agent memory ecosystem; see the [agent-memory-research](https://github.com/tobias-weiss-ai-xr/agent-memory-research) survey [[arXiv 2512.13564](https://arxiv.org/abs/2512.13564)] for the research foundation driving our memory architecture design.

## Features

- **Auto-registration** — `pi.registerProvider()` adds all 6 SAIA models on startup
- **Zero config** — API key from `auth.json`, `$SAIA_API_KEY` env var, or `/login saia`
- **Skill included** — `/skill:saia-models` documents available models and usage
- **OpenAI-compatible** — Uses standard `openai-completions` API

## Installation

```bash
# From git (recommended)
pi install git:github.com/tobias-weiss-ai-xr/pi-saia-plugin

# Or local
pi install /path/to/pi-saia-plugin
```

Then reload or restart pi:

```bash
/reload
```

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
# List available models
pi --list-models | grep ^saia

# Switch to a model
/model saia/glm-4.7

# With thinking level
/model saia/qwen3.5-397b-a17b:high

# Load the skill for documentation
/skill:saia-models
```

## API Key

The API key is resolved from (in order):

1. `auth.json` — `"saia": { "type": "api_key", "key": "..." }`
2. `$SAIA_API_KEY` environment variable
3. `/login saia` interactive prompt

## Package Structure

```
pi-saia-plugin/
├── package.json          # Pi package manifest
├── extensions/
│   └── index.ts          # Provider registration via registerProvider()
└── skills/
    └── saia-models.md    # Model documentation skill
```

## Development

```bash
git clone https://github.com/tobias-weiss-ai-xr/pi-saia-plugin.git
cd pi-saia-plugin
npm install
```

Test locally:

```bash
pi install /path/to/pi-saia-plugin
pi --list-models | grep ^saia
```

## License

MIT
