# Changelog

All notable changes to pi-saia-plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
