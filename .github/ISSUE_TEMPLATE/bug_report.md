---
name: Bug Report
about: Create a report to help us improve
title: ""
labels: bug
draft: false
---

## Bug Report

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. Use model '....'
3. See error '...'

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots/Logs**
If applicable, add screenshots or error logs to help explain your problem.

**Environment**
- OS: [e.g., Ubuntu 22.04, macOS 14, Windows 11]
- Node.js version: [e.g., 20.0.0]
- pi version: [e.g., latest]
- Plugin version: [e.g., 0.1.0]
- SAIA_PROFILE: [production/development/budget]

**Configuration**
```json
// Paste your relevant config (remove API keys!)
{
  "model": "saia/...",
  "provider": {
    "saia": {
      "options": {
        "baseURL": "...",
        "apiKey": "{env:SAIA_API_KEY}"
      }
    }
  }
}
```

**Additional context**
Add any other context about the problem here.
