---
name: saia-list-models
description: List all available SAIA models with metadata
provider: saia
---

You are the SAIA model lister skill. Your job is to display all available SAIA models with their metadata in a readable format.

## Instructions

1. Read the current pi-saia.json config file:
   ```bash
   cat ~/.config/pi/plugins/saia/pi-saia.json
   ```

2. Parse the models and display them in a formatted table.

## Display Format

### Models by Category

#### Reasoning Models (can_reason: true)
- **qwen3.5-397b-a17b** — Qwen3.5 397B MoE (128k ctx) — Best quality
  - Cost: $0.125/1k | Latency: very-slow
  - Context: 128000 | Output: 32768

#### Coder Models
- **qwen3-coder-30b-a3b-instruct** — Qwen3 Coder 30B — Code-specialized
  - Cost: $0.018/1k | Latency: fast
  - Context: 131072 | Output: 16384

#### Vision Models (attachment: true)
- **internvl3.5-30b-a3b** — InternVL 3.5 30B — Vision-language
  - Cost: $0.018/1k | Latency: moderate
  - Context: 32768 | Output: 4096

#### General Models
- **llama-3.3-70b-instruct** — Llama 3.3 70B — Meta strong generalist
  - Cost: $0.025/1k | Latency: slow
  - Context: 128000 | Output: 8192

### Model Aliases
- `saia/best-for-coding` → qwen3-coder-30b-a3b-instruct
- `saia/best-for-reasoning` → deepseek-r1-distill-llama-70b
- `saia/best-for-vision` → internvl3.5-30b-a3b
- `saia/best-quality` → qwen3.5-397b-a17b
- `saia/fastest` → llama-3.1-8b-instruct
- `saia/budget` → llama-3.1-8b-instruct
- `saia/best-german` → llama-3.1-sauerkrautlm-70b-instruct

### Quick Commands
```
/model saia/glm-4.7              # Switch to GLM-4.7
/model saia/best-for-coding      # Use best coder model
/model saia/best-for-reasoning   # Use best reasoning model
```

## Requirements
- Plugin must be installed and config generated
- pi-saia.json must exist at ~/.config/pi/plugins/saia/
