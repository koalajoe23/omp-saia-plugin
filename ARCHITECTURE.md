# Architecture

## Overview

The SAIA plugin for pi coding agent connects pi to SAIA (GWDG Chat AI) models through a layered architecture that provides caching, usage tracking, metrics, and profile-based model selection.

```
┌──────────────────────────────────────────────────┐
│                    pi Coding Agent                │
│                                                 │
│  ┌─────────────────────────────────────────────┐│
│  │              Plugin System                  ││
│  │                                              ││
│  │  ┌────────────────────────────────────────┐ ││
│  │  │           saia.ts (Plugin)              │ ││
│  │  │  - Plugin entry point for pi            │ ││
│  │  │  - Registers plugin with pi             │ ││
│  │  │  - Triggers config refresh on startup    │ ││
│  │  │  - Provides permissions configuration   │ ││
│  │  │  - Registers skills and commands        │ ││
│  │  └──────────┬───────────────────────────────┘ ││
│  │             │                              ││
│  │  ┌──────────▼──────────────────────────┐   ││
│  │  │        saia-memory.ts                 │   ││
│  │  │  - API cache (24h TTL)                  │   ││
│  │  │  - Usage tracking (JSONL)               │   ││
│  │  │  - Metrics collection                   │   ││
│  │  │  - User preferences                     │   ││
│  │  │  - Project context                      │   ││
│  │  │  - Model change detection               │   ││
│  │  └───────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────┘│
│                                                 │
│  ┌─────────────────────────────────────────────┐│
│  │         Skill Files (.opencode/skills/)     ││
│  │                                              ││
│  │  saia-refresh.md   - Force cache refresh   ││
│  │  saia-health.md    - API health check      ││
│  │  saia-list-models.md - List all models     ││
│  │  saia-switch-profile.md - Profile switcher ││
│  │  saia-optimize.md  - Model recommendations ││
│  └─────────────────────────────────────────────┘│
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│            SAIA API (GWDG Chat AI)               │
│  https://chat-ai.academiccloud.de/v1/models      │
│  https://chat-ai.academiccloud.de/v1/chat/...   │
└──────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│          Shell Scripts (src/*.sh)                │
│                                                  │
│  generate-saia-config.sh  - Main config gen      │
│  copy-saia-config.sh      - Copy to project      │
│  validate-config.sh       - JSON schema check    │
│  setup-wizard.sh          - Interactive setup    │
│  install.sh               - Auto-install         │
└──────────────────────────────────────────────────┘
```

## Data Flow

### Startup Flow

1. **pi starts** → loads plugin system
2. **saia.ts is loaded** → plugin registers itself
3. **refreshSaiaConfig() is called** → checks API cache (24h TTL)
4. **Cache hit** → uses cached model list
5. **Cache miss** → fetches from SAIA API via fetchModels() → caches result → generates config
6. **Config generated** → written to pi-saia.json
7. **pi reads config** → models become available to pi

### Model Request Flow

1. **User sends message** → pi processes request
2. **Model selection** → uses default from config or user-specified model
3. **Request sent** → pi uses @ai-sdk/openai-compatible to call SAIA API
4. **Usage logged** → saia-memory.ts logs the interaction
5. **Metrics updated** → latency, success/failure tracked

## Components

### 1. saia.ts (Main Plugin)

The TypeScript plugin that integrates with pi's plugin system.

**Responsibilities:**
- Plugin registration and initialization
- Fetching and caching model list from SAIA API
- Generating pi.json-compatible configuration
- Setting up permissions
- Registering skills and commands
- Model categorization and metadata generation

**Key Functions:**
- `fetchModels()`: Fetches model list from API
- `getModelMetadata()`: Generates metadata for a model
- `categorizeModel()`: Categorizes model by ID pattern
- `refreshSaiaConfig()`: Main configuration refresh logic
- `includeInProfile()`: Filters models by profile

### 2. saia-memory.ts (Memory Layer)

Utilities for caching, tracking, and metrics.

**Responsibilities:**
- **Caching**: API response cache with 24h TTL
- **Usage Tracking**: Per-project, per-model usage logging
- **Metrics**: Success rate, latency, error tracking
- **Preferences**: User preferences (favorite model, etc.)
- **Context**: Project-specific context and learning
- **Model Changes**: Detect new/removed models from API

**Storage Locations:**
```
~/.cache/saia/
├── models.json          # API response cache (24h TTL)
├── pi-models-list.json # Model ID list for change detection
├── pi-usage.jsonl      # Per-use tracking (JSON Lines)
└── pi-metrics.json     # Performance metrics

~/.config/pi/
├── saia-preferences.json # User preferences
└── plugins/saia/
    └── .pi/saia/
        └── context.json # Project context
```

### 3. Shell Scripts (src/*.sh)

Bash scripts for configuration management.

| Script | Purpose |
|--------|---------|
| `generate-saia-config.sh` | Main config generation with profiles |
| `copy-saia-config.sh` | Copy config to current directory |
| `validate-config.sh` | Validate pi.json against schema |
| `setup-wizard.sh` | Interactive installation guide |
| `install.sh` | One-click installer |
| `install.ps1` | Windows installer |

### 4. Skills (.opencode/skills/*.md)

pi-compatible skill files for SAIA management.

| Skill | Description |
|-------|-------------|
| `saia-refresh.md` | Force refresh model list from API |
| `saia-health.md` | Check API and plugin health |
| `saia-list-models.md` | List all available models |
| `saia-switch-profile.md` | Switch between profiles |
| `saia-optimize.md` | Get model recommendations |

### 5. Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `pi.json` | `~/.config/pi/` | Main pi configuration with plugin registration |
| `pi-saia.json` | `~/.config/pi/plugins/saia/` | Master SAIA model configuration |
| `pi-saia-{profile}.json` | `~/.config/pi/plugins/saia/` | Profile-specific configs |
| `pi.schema.json` | `schema/` | JSON schema for validation |

## Profiles

The plugin supports three model profiles:

| Profile | Model Count | Default Model | Use Case |
|---------|-------------|---------------|----------|
| **production** | ~8-9 | glm-4.7 | Critical work, highest quality |
| **development** | ~7-8 | qwen3.5-35b-a3b | Active development, balanced |
| **budget** | ~4 | llama-3.1-8b-instruct | Cost optimization |

### Profile Configuration

Profiles are configured via the `SAIA_PROFILE` environment variable:

```bash
# Production (default)
export SAIA_PROFILE=production

# Development
export SAIA_PROFILE=development

# Budget
export SAIA_PROFILE=budget
```

Each profile includes a specific set of models optimized for that use case. See `generate-saia-config.sh` for the exact model lists.

## Model Metadata

Each model in the configuration includes rich metadata:

### Standard Fields

```json
{
  "name": "Qwen3.5 397B MoE (128k ctx) — Flagship reasoning, best quality",
  "options": {
    "enable-tools": true,
    "enable-auto-tool-choice": true,
    "tool-call-parser": "openai"
  },
  "limit": {
    "context": 128000,
    "output": 32768
  }
}
```

### Extended Fields

```json
{
  "category": "reasoning",
  "description": "Qwen3.5 397B MoE (128k ctx) — Flagship reasoning, best quality",
  "can_reason": true,
  "attachment": false,
  "alias": false,
  "metadata": {
    "cost_per_1k_tokens": 0.125,
    "estimated_latency": "very-slow",
    "recommended_for": ["complex-reasoning", "high-quality-writing"]
  }
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable model name and description |
| `category` | string | Model category (reasoning/coder/vision/etc.) |
| `description` | string | Detailed description |
| `can_reason` | boolean | Supports chain-of-thought reasoning |
| `attachment` | boolean | Supports image/file input |
| `alias` | boolean | Is a model alias (not a real model) |
| `options` | object | Model-specific options |
| `limit.context` | integer | Maximum context window in tokens |
| `limit.output` | integer | Maximum output tokens |
| `metadata.cost_per_1k_tokens` | number | Estimated cost per 1,000 tokens (USD) |
| `metadata.estimated_latency` | string | Latency category (fast/moderate/slow/very-slow) |
| `metadata.recommended_for` | array | Use cases this model is recommended for |

## Model Categorization

Models are categorized based on their ID patterns and capabilities:

| Category | Pattern | Capability |
|----------|---------|------------|
| reasoning | thinking, r1, deepseek | Chain-of-thought reasoning |
| coder | coder | Code-specialized |
| vision | vl, vision, internvl | Image/file input |
| medical | med, gemma | Medical domain |
| research | teuken, sauerkraut | German/European research |
| agentic | glm-4.7, devstral | Tool use, agentic coding |
| large-context | 235b, 675b, 120b | 128k+ context |
| general | * | General-purpose |

## Permissions

The plugin defines default permissions for pi:

```json
{
  "bash": "allow",
  "edit": "allow",
  "read": "allow",
  "grep": "allow",
  "glob": "allow",
  "lsp": "allow",
  "skill": "allow",
  "task": "allow",
  "webfetch": "allow",
  "websearch": "allow",
  "question": "allow",
  "external_directory": "ask",
  "doom_loop": "ask"
}
```

These permissions can be customized by modifying the `PERMISSIONS` object in `saia.ts`.

## Cache Behavior

The plugin uses a 24-hour cache for the model list:

1. On startup, `fetchWithCache()` checks the cache
2. If cache is valid (< 24h old), returns cached data
3. If cache is invalid or missing, fetches fresh data
4. Fresh data is cached and used for subsequent requests

**Cache Files:**
- `~/.cache/saia/models.json`: Cached API response with timestamp
- `~/.cache/saia/pi-models-list.json`: Model ID list for change detection

**Force Refresh:**
```bash
# Delete cache files
rm ~/.cache/saia/models.json

# Or use incremental=false
SAIA_API_KEY=your_key bash generate-saia-config.sh --incremental=false
```

## Usage Tracking

The plugin tracks model usage for analytics and recommendations:

**Tracked Data:**
- Timestamp
- Project root directory
- Model ID
- Task type (inferred from context)
- Latency (milliseconds)

**Storage:**
- `~/.cache/saia/pi-usage.jsonl` (JSON Lines format)

**Example Entry:**
```json
{"timestamp":"2025-01-15T10:30:00.000Z","projectRoot":"/home/user/my-project","modelId":"qwen3.5-35b-a3b","taskType":"coding","latencyMs":450}
```

## Metrics Collection

The plugin collects performance metrics for each model/API operation:

**Tracked Metrics:**
- Request count
- Success count
- Error count
- Total latency
- Last used timestamp

**Storage:**
- `~/.cache/saia/pi-metrics.json`

**Example:**
```json
{
  "api": {
    "count": 42,
    "success": 40,
    "errors": 2,
    "totalLatency": 12500,
    "lastUsed": "2025-01-15T10:30:00.000Z"
  },
  "refresh": {
    "count": 5,
    "success": 5,
    "errors": 0,
    "totalLatency": 3500,
    "lastUsed": "2025-01-15T10:00:00.000Z"
  },
  "qwen3.5-35b-a3b": {
    "count": 20,
    "success": 19,
    "errors": 1,
    "totalLatency": 8000,
    "lastUsed": "2025-01-15T10:25:00.000Z"
  }
}
```

## Preferences

User preferences are stored and used for model recommendations:

**Storage:**
- `~/.config/pi/saia-preferences.json` (if it exists)

**Supported Preferences:**
- `favoriteModel`: User's preferred default model
- Any other custom preferences

**Example:**
```json
{
  "favoriteModel": "glm-4.7",
  ".defaultProfile": "development"
}
```

## Project Context

Project-specific context is stored for learning and recommendations:

**Storage:**
- `~/.config/pi/plugins/saia/.pi/saia/context.json` (per project)

**Supported Context:**
- `preferredModel`: Project-specific preferred model
- Any other project-specific preferences

## Error Handling

The plugin handles errors gracefully:

1. **API Errors**: Logs to console, updates metrics with failure
2. **Validation Errors**: Logs detailed error, continues with cached data
3. **Network Errors**: Retry logic in fetch, graceful degradation
4. **Permission Errors**: Returns meaningful error messages

Error messages are logged to console with the `[SAIA]` prefix for easy identification.

## Validation

The plugin includes JSON schema validation for configuration files:

**Schema:**
- `schema/pi.schema.json`: Full schema for pi.json validation

**Validation:**
```bash
# Validate current config
bash validate-config.sh pi.json

# Validate global config
bash validate-config.sh ~/.config/pi/pi.json
```

**Supported Validators:**
- `ajv-cli` (recommended): Full schema validation
- `jq` (fallback): Basic structure checks

## Dependencies

### Runtime Dependencies

| Dependency | Purpose | Optional |
|------------|---------|----------|
| Node.js >= 20 | TypeScript execution | No |
| curl | API requests | No |
| jq | JSON processing | No |

### Development Dependencies

| Dependency | Purpose |
|------------|---------|
| @types/node | TypeScript types |
| ajv-cli | Schema validation |

## Performance Considerations

1. **Startup Time**: The plugin adds minimal overhead to pi startup (~1-2 seconds for cache hit, ~3-5 seconds for fresh fetch)
2. **Memory**: Cache and config files are small (< 1MB total)
3. **Network**: Only one API call per 24 hours (cached)
4. **Disk I/O**: Minimal - only reads/writes config files

## Security Considerations

1. **API Key Storage**:
   - Stored in environment variables (in memory)
   - Can be persisted in shell config files
   - Referenced in pi.json as `{env:SAIA_API_KEY}` (not stored in plain text)

2. **Data Storage**:
   - All cached data is stored locally
   - No data is sent to external services
   - Usage tracking is purely local

3. **Permissions**:
   - Plugin has its own permission set
   - Can be customized by users
   - Sensitive operations require explicit permission

## Future Enhancements

Potential future features:

1. **Auto-refresh**: Background refresh of model list
2. **Custom Profiles**: User-defined model sets
3. **Model Testing**: Automated model capability testing
4. **Quota Monitoring**: Track SAIA quota usage
5. **Fallback Models**: Automatic fallback to similar models on failure
6. **Learning Recommendations**: AI-driven model recommendations based on usage
7. **Multi-provider**: Support for additional LLM providers alongside SAIA
