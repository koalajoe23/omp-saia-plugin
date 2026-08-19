# Changelog

All notable changes to omp-saia-plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automatic capability reconciliation: background cycle (startup + interval) keeps model list, reasoning, vision, and context windows fresh in a persisted store (`~/.omp/agent/saia-models.json`); env-configurable timing (`SAIA_RECONCILE_*`); manual `/saia-refresh` command

### Fixed
- Reasoning override set: added `gemma-4-31b-it` (verified against the live API, 2026-08-08)
- README model table: corrected reasoning column — `glm-4.7`, `devstral-2-123b-instruct-2512`, `qwen3-30b-a3b-instruct-2507`, and `medgemma-27b-it` do not emit reasoning under `reasoning_effort` (medgemma's endpoint is currently 500ing, so it stays unverified)
- Date-stamped model variants (e.g. `deepseek-v4-flash-0731`) now inherit reasoning support and context window from the base id: capability lookups strip a trailing `-NNNN` stamp (`baseModelId`), so variants no longer fall back to `reasoning: false` and the 128K default context window

## [1.0.0] - 2026-08-08

### Added
- Port of pi-saia-plugin to OMP (`@oh-my-pi/pi-coding-agent` extension API)
- `pi.registerProvider()` with `fetchDynamicModels` — OMP runtime discovery (24 h cache in `models.db`, `omp models refresh` to force)
- `thinking: { mode: "effort" }` + `compat.supportsReasoningEffort` replacing pi's `thinkingLevelMap`
- OMP skill layout (`skills/saia-models/SKILL.md`) and `omp.extensions` manifest
- `bun test` coverage for discovery/config transforms
- Removed pi-only machinery: shell config generators (`src/`), sandbox, Docker, pi installers, pi.json schema/example, pi CI workflows

## [Unreleased]

### Fixed
- **src/generate-saia-config.sh**: Heredoc with quoted `'HEADER'` delimiter prevented command substitution — `"model"` field contained literal `$(get_profile_default_model ...)` instead of the resolved model name
- **Dockerfile**: Fixed UID 1000 conflict with `node` user; fixed `CMD` format (JSON args); removed `ENV SAIA_API_KEY` (security); fixed `.opencode/skills/` not being copied (dotfile glob issue)
- **sandbox/run.sh**: Fixed invalid bash variable assignment containing Turkish/Azerbaijani characters (`üzrə`)
- **src/saia-memory.ts**: Fixed `MODELS_CACHE_FILE` used before its lexical declaration (TDZ risk)
- **test/test.sh**: Removed YAML files from JSON validation test (always failed)
- **src/setup-wizard.sh**: Fixed glob expansion with `nullglob` to prevent `cp` errors
- **CI workflow**: Tests now build and use local image instead of pulling from GHCR
- **src/saia.ts**: Fixed `registerCommand` call signatures to match pi's `ExtensionAPI`; skills from `.opencode/skills/` are now actually registered
- **TypeScript**: `extensions/index.ts` now included in type-checking; added missing `cost` field and `ProviderModelConfig` annotation
- **GHCR org**: All image references updated from `graphwiz-ai` to `tobias-weiss-ai-xr`

### Added
- Initial repository structure
- TypeScript plugin for pi coding agent
- SAIA API integration
- Profile-based model selection (production, development, budget)
- Memory layer with caching, metrics, and usage tracking
- 5 management skills: refresh, health, list-models, switch-profile, optimize
- Shell scripts for configuration generation
- Interactive setup wizard
- Comprehensive documentation

### Changed
- TypeScript type definitions improved
- Fixed import statements for Node.js modules
- Enhanced error handling in memory layer

---

## [1.0.0] - 2025-07-27

### Added
- **Pi package format**: Now installable via `pi install` (following the pi-memory pattern — see [agent-memory-research](https://github.com/tobias-weiss-ai-xr/agent-memory-research) survey [[arXiv 2512.13564](https://arxiv.org/abs/2512.13564)] for the research foundation behind our memory architecture)
- **Provider auto-registration**: Extension registers SAIA provider with 6 models via `pi.registerProvider()`
- **Usage skill**: `/skill:saia-models` documents available models and usage
- **Clean `package.json` manifest**: `pi` key with `extensions` and `skills` paths

### Changed
- **Architecture**: From shell-script config generator → pi package with TypeScript extension
- **README**: Updated to describe pi package installation, usage, and structure
- API key resolution now uses pi's built-in auth stack (auth.json / env vars / /login) instead of shell scripts

### Removed
- Shell scripts (`src/*.sh`) — superseded by pi package auto-registration
- Docker setup — no longer needed; pi packages are self-contained
- Sandbox, showcase, Makefile — legacy from old approach

---

## [0.1.0] - 2025-07-25

### Added
- **Core Plugin** (`src/saia.ts`): Main plugin entry point for pi
- **Memory Layer** (`src/saia-memory.ts`): Caching, usage tracking, metrics
- **Configuration Generation** (`src/generate-saia-config.sh`): Fetches models from SAIA API
- **Utility Scripts**: copy, validate, setup-wizard
- **Skills**: 5 SAIA management skills in `.opencode/skills/`
- **Documentation**: README, FAQ, ARCHITECTURE, SECURITY, ROADMAP
- **Installation**: Shell and PowerShell installers

### Features
- Automatic model list refresh on pi startup
- 24-hour caching of API responses
- Profile support (production, development, budget)
- Rich model metadata (category, limits, costs, latency)
- Model aliases for easy selection
- JSON schema validation
- LiteLLM proxy support

### Model Categories
- Reasoning (chain-of-thought)
- Coder (code-specialized)
- Vision (multimodal)
- Medical
- Research
- Agentic (tool use)
- Large Context (≥128k tokens)
- General

### Model Aliases
- `saia/best-for-coding` → qwen3-coder-30b
- `saia/best-for-reasoning` → deepseek-r1-distill-llama-70b
- `saia/best-for-vision` → internvl3.5-30b
- `saia/best-for-agentic` → glm-4.7
- `saia/best-quality` → qwen3.5-397b
- `saia/fastest` → llama-3.1-8b
- `saia/budget` → llama-3.1-8b
- `saia/best-german` → llama-3.1-sauerkrautlm-70b

### Profiles
| Profile | Models | Default | Use Case |
|---------|--------|---------|----------|
| production | ~8-9 | glm-4.7 | Critical work, highest quality |
| development | ~7-8 | qwen3.5-35b-a3b | Active development, balanced |
| budget | ~4 | llama-3.1-8b | Cost optimization |

---

## [0.0.1] - 2025-07-24

### Added
- Project conception
- Repository initialization
- Basic structure based on opencode-saia-plugin

[Unreleased]: https://github.com/tobias-weiss-ai-xr/pi-saia-plugin/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/tobias-weiss-ai-xr/pi-saia-plugin/releases/tag/v0.1.0
[0.0.1]: https://github.com/tobias-weiss-ai-xr/pi-saia-plugin/releases/tag/v0.0.1
