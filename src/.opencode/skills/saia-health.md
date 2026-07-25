---
name: saia-health
description: Check the health status of the SAIA API and plugin
provider: saia
---

You are the SAIA health check skill. Your job is to verify that:
1. The SAIA API is accessible
2. The API key is valid
3. The plugin is properly configured

## Instructions

1. **API Connectivity Test**:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" \
     "https://chat-ai.academiccloud.de/v1/models" \
     -H "Authorization: Bearer {env:SAIA_API_KEY}"
   ```

2. **Plugin Installation Check**:
   ```bash
   ls ~/.config/pi/plugins/saia/saia.ts
   ```

3. **Config File Check**:
   ```bash
   ls -la ~/.config/pi/plugins/saia/pi-saia.json
   ```

4. **PI Config Check**:
   ```bash
   grep -q '"saia"' ~/.config/pi/pi.json && echo "Plugin registered" || echo "Plugin NOT registered"
   ```

## Health Status Report

Based on the results, provide a comprehensive health report:

- **API Status**: ✓ Reachable | ✗ Unreachable
- **API Key**: ✓ Valid | ✗ Invalid/Expired
- **Plugin Files**: ✓ Installed | ✗ Missing
- **Model Config**: ✓ Present (X models) | ✗ Missing
- **PI Registration**: ✓ Registered | ✗ Not registered

## Troubleshooting

If any checks fail, provide specific remediation steps:
- API unreachable: Check network, firewall, or SAIA server status
- Invalid key: Verify SAIA_API_KEY value at https://chat-ai.academiccloud.de
- Plugin missing: Re-run the install script
- Config missing: Run generate-saia-config.sh
- Not registered: Add "saia" to plugin array in pi.json
