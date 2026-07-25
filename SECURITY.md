# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in pi-saia-plugin, please report it responsibly:

1. **Do NOT** create a public GitHub/Codeberg issue
2. **Do NOT** discuss it in public channels
3. **DO** report it privately via email:
   - Security issues: security@graphwiz-ai.com (or open an issue marked as security advisory)
   - General bugs: Use the regular issue tracker

## Security Features

### API Key Handling
- **Never stored in plain text** in configuration files (uses `{env:SAIA_API_KEY}`)
- **Stored in environment variables** (in memory only)
- **Optional persistence** in shell config files (user-controlled)

### Data Collection
All data collected by the plugin is **local-only**:

| Data Type | Location | Purpose |
|-----------|----------|---------|
| API Key | Environment variable | Authentication |
| Model Cache | `~/.cache/saia/models.json` | Reduce API calls |
| Usage Logs | `~/.cache/saia/pi-usage.jsonl` | Track model usage |
| Metrics | `~/.cache/saia/pi-metrics.json` | Performance monitoring |
| Preferences | `~/.config/pi/saia-preferences.json` | User settings |

**No data is ever sent to external services.**

### Network Security
- Uses **HTTPS** for all API requests
- Supports **LiteLLM proxy** for additional security layer
- **30-second timeout** on API requests
- **No telemetry** or analytics sent to third parties

### File Permissions
- Generated config files: `644` (readable by owner)
- Cache directory: `755` (owner read/write/execute)
- Shell scripts: `755` (executable)

## Best Practices

### For Users

1. **Use environment variables** for API keys, not hardcoded in scripts
2. **Set restrictive file permissions** on config directories:
   ```bash
   chmod 700 ~/.config/pi
   chmod 700 ~/.cache/saia
   ```
3. **Use LiteLLM proxy** for:
   - Rate limiting
   - Request logging
   - Caching
   - Fallback to other providers
4. **Regularly rotate** your SAIA API key
5. **Review** your Codeberg/GitHub repository settings if forking

### For Developers

1. **Never log** API keys or sensitive data
2. **Validate all inputs** from users and APIs
3. **Use parameterized queries** (not applicable here, but good practice)
4. **Handle errors gracefully** without exposing sensitive information
5. **Keep dependencies updated**

## Vulnerability Response

### Assessment
1. Confirm the vulnerability and determine severity
2. Identify affected versions
3. develop a fix or mitigation

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| **Critical** | Remote code execution, API key exposure | <24 hours |
| **High** | Privilege escalation, data leak | <48 hours |
| **Medium** | Denial of service, information disclosure | <72 hours |
| **Low** | Minor issues with limited impact | <1 week |

### Disclosure
1. Fix is prepared and tested
2. Security advisory is drafted
3. Fix is released with CVE if applicable
4. Public disclosure after users have had time to update

## Security Updates

| Date | Issue | Action |
|------|-------|--------|
| 2025-07-25 | Initial security policy | Created |

## Contact

For security-related questions:
- Email: security@graphwiz-ai.com
- GitHub: [@tobias-weiss-ai-xr](https://github.com/tobias-weiss-ai-xr)
- Codeberg: [@graphwiz-ai](https://codeberg.org/graphwiz-ai)
