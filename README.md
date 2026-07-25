# SAIA Plugin for pi Coding Agent

[pi](https://github.com/earendil-works/pi-coding-agent) plugin that adds all [SAIA](https://chat-ai.academiccloud.de) (GWDG Chat AI) models to your pi setup.

## What It Does

1. **Fetches the latest model list** from the SAIA API
2. **Generates a pi.json** with all SAIA models, properly categorized
3. **Provides rich metadata** for each model (capabilities, limits, costs)
4. **Supports profiles** (production, development, budget)
5. **Includes skills** for model management and optimization

## Installation

### Prerequisites
- `SAIA_API_KEY` environment variable set
- `curl` and `jq` installed
- Node.js >= 20.0.0 (for TypeScript support)

### Quick Install

**Linux/macOS:**
```bash
# Clone the repo
git clone https://codeberg.org/graphwiz-ai/pi-saia-plugin.git
cd pi-saia-plugin

# Install plugin
bash install.sh
```

**Windows PowerShell:**
```powershell
git clone https://codeberg.org/graphwiz-ai/pi-saia-plugin.git
cd pi-saia-plugin
./install.ps1
```

### Manual Installation

```bash
# Create plugin directory
mkdir -p ~/.config/pi/plugins/saia

# Copy plugin files
cp -r src/* ~/.config/pi/plugins/saia/
chmod +x ~/.config/pi/plugins/saia/*.sh

# Add plugin to pi config
cat > ~/.config/pi/pi.json <<'EOF'
{
  "$schema": "https://pi.code/config.json",
  "plugin": ["saia"],
  "model": "saia/glm-4.7"
}
EOF
```

### Set API Key

**Permanent (recommended):**
```bash
# Linux/macOS
echo 'export SAIA_API_KEY="your_key_here"' >> ~/.bashrc
source ~/.bashrc

# Windows PowerShell
[Environment]::SetEnvironmentVariable("SAIA_API_KEY", "your_key_here", "User")
```

**Temporary (for testing):**
```bash
export SAIA_API_KEY=your_key_here
pi
```

## Interactive Setup Wizard

For first-time users, the interactive wizard guides you through the entire setup:

```bash
bash src/setup-wizard.sh
```

The wizard will:
1. **Validate your SAIA API key** against the live API
2. **Select a profile** (production / development / budget)
3. **Install plugin files** to `~/.config/pi/plugins/saia/`
4. **Generate config** with your chosen profile
5. **Persist your API key** in your shell config

## Usage

### Starting pi with SAIA

Once installed, pi will automatically load SAIA models:

```bash
pi
```

### Switching Models

Use the model command to switch between SAIA models:

```
/model saia/glm-4.7              # Use GLM-4.7
/model saia/qwen3.5-35b-a3b      # Use Qwen3.5 35B
/model saia/best-for-coding      # Use coded-optimized model
/model saia/best-for-reasoning   # Use reasoning-optimized model
```

### Available Model Aliases

| Alias | Model | Use Case |
|-------|-------|----------|
| `saia/best-for-coding` | qwen3-coder-30b | Code-specialized tasks |
| `saia/best-for-reasoning` | deepseek-r1-distill-llama-70b | Complex reasoning, math |
| `saia/best-for-vision` | internvl3.5-30b-a3b | Image analysis, multimodal |
| `saia/best-for-agentic` | glm-4.7 | Agentic coding, tool use |
| `saia/best-quality` | qwen3.5-397b-a17b | Highest quality output |
| `saia/fastest` | llama-3.1-8b-instruct | Fastest response time |
| `saia/budget` | llama-3.1-8b-instruct | Lowest cost |
| `saia/best-german` | llama-3.1-sauerkrautlm-70b | German language tasks |

### Manual Configuration Generation

```bash
# Generate fresh config
cd ~/.config/pi/plugins/saia
SAIA_API_KEY=your_key bash generate-saia-config.sh

# Use a specific profile
SAIA_PROFILE=development SAIA_API_KEY=your_key bash generate-saia-config.sh

# Force refresh (bypass cache)
SAIA_API_KEY=your_key bash generate-saia-config.sh --incremental=false
```

## Profiles

### Production Profile
- **Model Count**: ~8-9
- **Default**: glm-4.7
- **Best for**: Critical work, highest quality
- **Models**: qwen3.5-397b, qwen3.5-122b, qwen3-235b, mistral-large-3-675b, glm-4.7, devstral-2, deepseek-r1, vision models

### Development Profile
- **Model Count**: ~7-8
- **Default**: qwen3.5-35b-a3b
- **Best for**: Active development, balanced cost/quality
- **Models**: qwen3.5-35b, qwen3.5-27b, qwen3-32b, llama-3.3-70b, gemma-3-27b, gemma-4-31b, coder models

### Budget Profile
- **Model Count**: ~4
- **Default**: llama-3.1-8b-instruct
- **Best for**: Cost optimization, fastest responses
- **Models**: llama-3.1-8b, teuken-7b, gemma-3-27b

Switch profiles:
```bash
SAIA_PROFILE=development bash generate-saia-config.sh
```

## Skills

The plugin includes useful skills for managing SAIA models:

| Skill | Description | Usage |
|-------|-------------|-------|
| `saia-refresh` | Force refresh model list from API | `/skill saia-refresh` |
| `saia-health` | Check API and plugin health | `/skill saia-health` |
| `saia-list-models` | List all available models | `/skill saia-list-models` |
| `saia-switch-profile` | Switch between profiles | `/skill saia-switch-profile` |
| `saia-optimize` | Get model recommendations | `/skill saia-optimize` |

## Rate Limits

SAIA enforces the following rate limits (shared across all models):

- **30 requests/min** · **200/hour** · **1,000/day** · **3,000/month**

When limits are exhausted, the API returns 429 errors. Check remaining quota at the [SAIA dashboard](https://chat-ai.academiccloud.de).

## LiteLLM Proxy Support (Optional)

If you have a LiteLLM proxy running (e.g., with SAIA models configured), you can route all requests through it for caching, rate limiting, and fallback support:

```bash
export LITELLM_PROXY_URL=http://your-proxy:4000/v1
```

Then regenerate the config. The plugin will use the proxy URL instead of the direct SAIA API.

```bash
SAIA_API_KEY=your_key LITELLM_PROXY_URL=http://your-proxy:4000/v1 \
  bash generate-saia-config.sh
```

## Model Categories

The plugin categorizes models for easy filtering:

| Category | Models | Capability |
|----------|--------|------------|
| **Reasoning** | Qwen3.5 397B/122B/35B/27B, GLM-4.7, DeepSeek R1 | Chain-of-thought reasoning (`can_reason: true`) |
| **Coder** | Qwen3 Coder 30B | Code-specialized |
| **Vision** | Qwen3 VL 30B, InternVL 3.5 30B, Qwen3.6 35B | Multimodal, image/file input (`attachment: true`) |
| **Medical** | MedGemma 27B | Medical domain specialist |
| **Research** | Teuken 7B, SauerkrautLM 70B | German/European research |
| **Agentic** | GLM-4.7, Devstral 2 | Strong tool-use and agentic coding |
| **Large Context** | Qwen3 235B, Mistral Large 3 675B, GPT-OSS 120B | 128k+ context windows |
| **General** | Llama 3.3 70B, Gemma 3/4, Qwen3 32B, etc. | General-purpose |

## Model Metadata

Each model in the generated config includes:

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Human-readable description | "Qwen3.5 397B MoE (128k ctx) — Flagship reasoning, best quality" |
| `category` | Model category | "reasoning" |
| `can_reason` | Supports CoT reasoning | `true` |
| `attachment` | Supports image/file input | `true` (vision models) |
| `limit.context` | Max context tokens | 128000 |
| `limit.output` | Max output tokens | 32768 |
| `metadata.cost_per_1k_tokens` | Estimated cost in USD | 0.125 |
| `metadata.estimated_latency` | Latency category | "fast", "moderate", "slow", "very-slow" |
| `metadata.recommended_for` | Use cases | ["complex-reasoning", "high-quality-writing"] |

## Configuration Validation

Validate your pi.json before using it:

```bash
# Validate current project configuration
bash validate-config.sh pi.json

# Validate global pi config
bash validate-config.sh ~/.config/pi/pi.json
```

**Requirements:**
- `ajv-cli` (recommended): `npm install -g ajv-cli` (full schema validation)
- `jq` (fallback): `apt install jq` or `brew install jq` (basic structure checks)

## Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| Plugin not loading | Script not found or not executable | Check `~/.config/pi/plugins/saia/` exists and has correct permissions |
| Models not showing | Invalid API key or network issue | Verify API key at [SAIA dashboard](https://chat-ai.academiccloud.de) |
| `curl: command not found` | Missing `curl` | Install: `sudo apt install curl` or `brew install curl` |
| `jq: command not found` | Missing `jq` | Install: `sudo apt install jq` or `brew install jq` |
| 429 errors | Rate limit exhausted | Wait or check dashboard quota |
| Config not updating | Cache still valid | Use `--incremental=false` or wait 24 hours |

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `SAIA_API_KEY` | Yes | API key for GWDG Chat AI service |
| `SAIA_PROFILE` | No | Model profile (production/dev/budget), default: production |
| `LITELLM_PROXY_URL` | No | Optional LiteLLM proxy URL for caching/rate limiting |

## Files

| File | Purpose |
|------|---------|
| `src/saia.ts` | Main plugin entry point |
| `src/saia-memory.ts` | Memory layer (caching, usage tracking, metrics) |
| `src/generate-saia-config.sh` | Fetches models, generates pi.json |
| `src/copy-saia-config.sh` | Copies config to current directory |
| `src/validate-config.sh` | JSON schema validator |
| `src/setup-wizard.sh` | Interactive setup guide |
| `schema/pi.schema.json` | JSON schema for validation |
| `install.sh`/`install.ps1` | One-click installers |
| `.opencode/skills/*.md` | SAIA management skills |

## Comparison with OpenCode SAIA Plugin

This plugin is based on the [opencode-saia-plugin](https://codeberg.org/graphwiz-ai/opencode-saia-plugin) but adapted for pi coding agent:

| Feature | OpenCode Plugin | pi Plugin |
|---------|----------------|-----------|
| Agent | OpenCode | pi |
| Config file | opencode.json | pi.json |
| Plugin directory | ~/.config/opencode/plugins/saia | ~/.config/pi/plugins/saia |
| Main script | saia.ts (OpenCode) | saia.ts (pi) |
| API compatibility | ✓ | ✓ |
| Profiles | ✓ | ✓ |
| Model metadata | ✓ | ✓ |
| Caching | ✓ | ✓ |
| Skills | ✓ | ✓ |
| Memory layer | ✓ | ✓ |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Repository

- **Primary**: [Codeberg](https://codeberg.org/graphwiz-ai/pi-saia-plugin)
- **Issues**: [Codeberg Issues](https://codeberg.org/graphwiz-ai/pi-saia-plugin/issues)

## Contributing

Contributions welcome! Please open issues or pull requests on Codeberg.

## Acknowledgments

- [GWDG Chat AI (SAIA)](https://chat-ai.academiccloud.de) - Model provider
- [pi Coding Agent](https://github.com/earendil-works/pi-coding-agent) - Host agent
- [OpenCode SAIA Plugin](https://codeberg.org/graphwiz-ai/opencode-saia-plugin) - Inspiration and code base
