# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in omp-saia-plugin, please report it responsibly:

1. **Do NOT** create a public GitHub issue
2. **Do NOT** discuss it in public channels
3. **DO** report it privately via email:
   - Security issues: security@tobias-weiss-ai-xr.dev (or open an issue marked as security advisory)
   - General bugs: Use the regular issue tracker

## Security Features

### API Key Handling
- The API key is read from the `SAIA_API_KEY` environment variable (including OMP's `.env` loading); it is never written to configuration files by this plugin
- When the key is present at registration it is handed to OMP as a config-sourced credential (in-memory, OMP's auth store)

### Data Collection
All data collected by the plugin is **local-only**:

| Data Type | Location | Purpose |
|-----------|----------|---------|
| API Key | Environment variable | Authentication |
| Model Cache | OMP's model cache DB (`models.db`, 24 h TTL) | Reduce API calls |

### Network Access
The plugin only talks to the SAIA API endpoints (`chat-ai.academiccloud.de/v1/models` and the configured base URL). It runs as an in-process OMP extension with no sandbox — same trust model as any other OMP extension.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x (OMP port) | ✅ |
| pi-saia-plugin (pre-port) | ❌ — see the [pi repo](https://github.com/tobias-weiss-ai-xr/pi-saia-plugin) |
