# Frequently Asked Questions

## General

### What is SAIA?

SAIA (Scientific AI Assistant) is a Chat AI service provided by GWDG (Gesellschaft fÃ¼r wissenschaftliche Datenverarbeitung mbH Göttingen). It offers access to a variety of cutting-edge large language models for academic and research purposes.

- **Website**: https://chat-ai.academiccloud.de
- **API Documentation**: https://chat-ai.academiccloud.de/docs/api

### What is this plugin?

This plugin integrates SAIA models into the [pi coding agent](https://github.com/earendil-works/pi-coding-agent), allowing you to use SAIA's models as providers within pi.

### How does it work?

1. The plugin fetches the latest model list from SAIA's API
2. It generates a configuration file (`pi.json`) with all available models
3. Each model includes rich metadata (capabilities, limits, costs)
4. pi loads the plugin and makes all SAIA models available

## Installation

### I installed the plugin but models aren't showing up

Check these things:

1. **API Key**: Ensure `SAIA_API_KEY` is set and valid
   ```bash
   echo $SAIA_API_KEY  # Should show your key
   ```

2. **Plugin registration**: Check your `~/.config/pi/pi.json` has the plugin registered
   ```json
   {
     "plugin": ["saia"]
   }
   ```

3. **Plugin files**: Verify the plugin is installed
   ```bash
   ls ~/.config/pi/plugins/saia/saia.ts
   ```

4. **Config file**: Check if the model config was generated
   ```bash
   ls ~/.config/pi/plugins/saia/pi-saia.json
   ```

### How do I verify my API key?

Test your API key with curl:

```bash
curl -s -o /dev/null -w "%{http_code}" \
  "https://chat-ai.academiccloud.de/v1/models" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

A successful response returns `200`. Any other code means your key is invalid or expired.

### Can I install without the wizard?

Yes! Run these commands:

```bash
# Clone
git clone https://github.com/tobias-weiss-ai-xr/pi-saia-plugin.git
cd pi-saia-plugin

# Install
mkdir -p ~/.config/pi/plugins/saia
cp -r src/* ~/.config/pi/plugins/saia/
chmod +x ~/.config/pi/plugins/saia/*.sh

# Configure
cat > ~/.config/pi/pi.json <<'EOF'
{
  "$schema": "https://pi.code/config.json",
  "plugin": ["saia"],
  "model": "saia/glm-4.7"
}
EOF

# Generate models
export SAIA_API_KEY=your_key_here
bash ~/.config/pi/plugins/saia/generate-saia-config.sh
```

## Usage

### How do I switch models?

Use pi's model switching command:

```
/model saia/glm-4.7           # Use GLM-4.7
/model saia/qwen3.5-35b-a3b   # Use Qwen3.5 35B
/model saia/best-for-coding   # Use coding alias
```

### What are model aliases?

Aliases provide shortcuts to models optimized for specific tasks:

| Alias | Points To | Use Case |
|-------|-----------|----------|
| `best-for-coding` | qwen3-coder-30b | Code-specialized |
| `best-for-reasoning` | deepseek-r1-distill-llama-70b | Complex reasoning |
| `best-for-vision` | internvl3.5-30b-a3b | Image analysis |
| `best-for-agentic` | glm-4.7 | Agentic coding |
| `best-quality` | qwen3.5-397b-a17b | Highest quality |
| `fastest` | llama-3.1-8b | Fastest response |
| `budget` | llama-3.1-8b | Lowest cost |
| `best-german` | llama-3.1-sauerkrautlm-70b | German tasks |

### How do I see all available models?

Use the list models skill:

```
/skill saia-list-models
```

Or check the config file directly:

```bash
jq '.provider.saia.models | keys' ~/.config/pi/plugins/saia/pi-saia.json
```

### The model list is outdated. How do I refresh?

Force a refresh from the API:

```
/skill saia-refresh
```

Or manually:

```bash
SAIA_API_KEY=your_key bash ~/.config/pi/plugins/saia/generate-saia-config.sh --incremental=false
```

### Why is my config not updating?

The plugin caches the model list for 24 hours. To force a refresh:

1. Delete the cache:
   ```bash
   rm ~/.cache/saia/models.json
   ```

2. Or use the `--incremental=false` flag:
   ```bash
   bash ~/.config/pi/plugins/saia/generate-saia-config.sh --incremental=false
   ```

## Profiles

### What are profiles?

Profiles are pre-configured model sets for different use cases:

| Profile | Models | Use Case |
|---------|--------|----------|
| **production** | ~8-9 highest quality | Critical work |
| **development** | ~7-8 balanced | Active development |
| **budget** | ~4 cheapest | Cost optimization |

### How do I switch profiles?

Set the `SAIA_PROFILE` environment variable before generating the config:

```bash
# For current session
SAIA_PROFILE=development bash ~/.config/pi/plugins/saia/generate-saia-config.sh

# Permanent
add to ~/.bashrc: export SAIA_PROFILE=development
```

### Why would I use a profile?

- **Production**: You want the best quality models and don't mind higher costs/latency
- **Development**: You want a balance of quality and speed for active coding
- **Budget**: You want the cheapest/fastest models for simple tasks

### Can I create a custom profile?

Currently, custom profiles aren't supported directly. However, you can:

1. Use the development or production profile as a base
2. Manually edit the generated `pi-saia.json` to remove unwanted models
3. Create a custom script based on `generate-saia-config.sh`

## Models

### Which model should I use?

Use the optimize skill for recommendations:

```
/skill saia-optimize
```

Or refer to this quick guide:

| Task | Best Model | Alternative |
|------|------------|-------------|
| Coding | qwen3-coder-30b or glm-4.7 | devstral-2-123b |
| Reasoning | qwen3.5-397b-a17b | deepseek-r1-distill-llama-70b |
| Vision | internvl3.5-30b-a3b | qwen3-vl-30b |
| German | llama-3.1-sauerkrautlm-70b | teuken-7b |
| Quick tasks | llama-3.1-8b | gemma-3-27b |
| Large context | qwen3-235b-a22b | mistral-large-3-675b |

### What models support reasoning?

Models with `can_reason: true`:

- qwen3.5-397b-a17b
- qwen3.5-122b-a10b
- qwen3.5-35b-a3b
- qwen3.5-27b
- qwen3.6-35b-a3b
- glm-4.7
- qwen3-235b-a22b
- qwen3-30b-a3b-thinking-2507
- deepseek-r1-distill-llama-70b

### What models support image input?

Models with `attachment: true` (vision models):

- qwen3-vl-30b-a3b-instruct
- internvl3.5-30b-a3b
- qwen3.6-35b-a3b
- qwen3-omni-30b-a3b-instruct

### What are the rate limits?

SAIA enforces these limits (shared across all models):

- **30 requests/minute**
- **200 requests/hour**
- **1,000 requests/day**
- **3,000 requests/month**

Check your quota at: https://chat-ai.academiccloud.de

### Can I increase my rate limit?

Rate limits are set by GWDG/SAIA. Contact their support if you need higher limits for legitimate academic/research use.

### What context window do models have?

Most models support 128,000 tokens (128k). Some have different limits:

- **128k**: Most models (qwen3.5-*, mistral-large-3, glm-4.7, llama-3.*)
- **131k**: gemma-3-27b, gemma-4-31b, qwen3-coder, qwen3-30b-*
- **32k**: Vision models (qwen3-vl, internvl, qwen3-omni, medgemma, teuken)

## LiteLLM Proxy

### What is LiteLLM?

[LiteLLM](https://github.com/BerriAI/litellm) is a lightweight proxy that provides a unified interface for multiple LLM providers, including caching, rate limiting, and fallback support.

### How do I use LiteLLM with this plugin?

1. Set up LiteLLM with SAIA models configured
2. Set the proxy URL:
   ```bash
   export LITELLM_PROXY_URL=http://your-proxy:4000/v1
   ```
3. Regenerate the config:
   ```bash
   SAIA_API_KEY=dummy LITELLM_PROXY_URL=http://your-proxy:4000/v1 \
     bash generate-saia-config.sh
   ```

The plugin will use the proxy instead of calling SAIA directly.

### Why use a LiteLLM proxy?

- **Caching**: Reduce API calls and improve response times
- **Rate limiting**: Manage your SAIA quota more effectively
- **Fallback**: Automatically switch to backup models if one fails
- **Multi-provider**: Route requests to different providers based on model

## Troubleshooting

### I get 429 errors

You've hit the SAIA rate limit. Options:

1. Wait for the limit to reset (1 hour for hourly, 1 day for daily)
2. Use a LiteLLM proxy with caching
3. Switch to a budget profile with fewer/smaller models
4. Check your quota at https://chat-ai.academiccloud.de

### I get 401 errors

Your API key is invalid or expired. Regenerate it at https://chat-ai.academiccloud.de and update your `SAIA_API_KEY`.

### The script hangs or times out

The SAIA API might be slow or unreachable. Try:

- Increasing the timeout (edit the script)
- Using a LiteLLM proxy
- Checking SAIA server status

### Invalid JSON errors

This usually means the API returned unexpected data. Try:

1. Force refresh: `bash generate-saia-config.sh --incremental=false`
2. Check the raw API response:
   ```bash
   curl -s "https://chat-ai.academiccloud.de/v1/models" \
     -H "Authorization: Bearer $SAIA_API_KEY" | jq
   ```
3. Report the issue if the data looks valid

### Models not showing in pi

1. Restart pi
2. Verify the plugin is loaded: check pi logs for "SAIA Plugin" messages
3. Check `~/.config/pi/plugins/saia/pi-saia.json` exists
4. Verify `~/.config/pi/pi.json` has `"plugin": ["saia"]`

### Plugin not loading at all

1. Check plugin directory exists: `ls ~/.config/pi/plugins/saia/`
2. Check saia.ts is present: `ls ~/.config/pi/plugins/saia/saia.ts`
3. Check permissions: `ls -la ~/.config/pi/plugins/saia/` (should be readable)
4. Try manual execution: `node ~/.config/pi/plugins/saia/saia.ts`

## Development

### How do I contribute?

1. Fork the repository on Codeberg
2. Create a feature branch
3. Make your changes
4. Submit a pull request

### How do I test changes?

1. Make changes in the repo
2. Copy updated files to `~/.config/pi/plugins/saia/`
3. Restart pi and test

### Can I add custom models?

Yes! Edit the `categorize()`, `describe()`, and related functions in `generate-saia-config.sh` to add metadata for new models.

## Comparison with Other Tools

### How is this different from the OpenCode SAIA plugin?

The OpenCode plugin is for the [OpenCode](https://github.com/kubeopencode/opencode) AI assistant, while this plugin is for [pi](https://github.com/earendil-works/pi-coding-agent). They share similar architecture and features but are designed for different host agents.

### Can I use both plugins?

Yes! They're independent. You can use the OpenCode plugin with OpenCode and this plugin with pi, both using the same SAIA API key.

### Will this plugin work with other agents?

This plugin is specifically designed for pi. However, the configuration generation scripts (`generate-saia-config.sh`) can be adapted for other agents that support OpenAI-compatible APIs.

## Privacy & Security

### Is my API key secure?

The plugin stores your API key in:
1. Environment variables (in memory)
2. Your shell config file (if you used the wizard)
3. The pi.json config file (as `{env:SAIA_API_KEY}`, which references the env var)

The key is never stored in plain text in the generated config files.

### What data is logged?

The plugin logs:
- Model usage (model ID, timestamp, project root) to `~/.cache/saia/pi-usage.jsonl`
- API metrics (success/failure, latency) to `~/.cache/saia/pi-metrics.json`
- Model list cache to `~/.cache/saia/models.json`

This data is only stored locally and never sent to any external service.

### Can I disable logging?

Yes. To disable usage logging, modify or remove the `logUsage()` calls in `saia.ts` and `saia-memory.ts`.

## Support

### Where can I get help?

1. Check this FAQ
2. Open an issue on [Codeberg](https://github.com/tobias-weiss-ai-xr/pi-saia-plugin/issues)
3. Check the [SAIA documentation](https://chat-ai.academiccloud.de/docs)

### How do I report bugs?

When reporting bugs, please include:

- pi version
- Plugin version
- Node.js version
- OS and platform
- Steps to reproduce
- Error messages (from console or logs)
- Your `SAIA_PROFILE` (if not default)

### How do I request features?

Open an issue on Codeberg with your feature request. Please include:

- Description of the feature
- Use case or problem it solves
- Any relevant examples or mockups
