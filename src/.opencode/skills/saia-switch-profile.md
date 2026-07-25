---
name: saia-switch-profile
description: Switch between SAIA profiles (production, development, budget)
provider: saia
---

You are the SAIA profile switcher skill. Your job is to help users switch between different SAIA model profiles.

## Available Profiles

| Profile | Models | Use Case | Default |
|---------|----------|----------|---------|
| **production** | ~8-9 highest quality | Critical work, best quality | glm-4.7 |
| **development** | ~7-8 balanced | Active development, faster | qwen3.5-35b |
| **budget** | ~4 cheapest | Cost optimization | llama-3.1-8b |

## Instructions

### Step 1: Ask for profile choice
"Which profile would you like to switch to? (production/development/budget)"

### Step 2: Update environment variable
Set the SAIA_PROFILE environment variable:
```bash
# For current session
export SAIA_PROFILE=<chosen-profile>

# To make permanent, also add to shell config
if ! grep -q "SAIA_PROFILE" ~/.bashrc; then
    echo "export SAIA_PROFILE=<chosen-profile>" >> ~/.bashrc
fi
```

### Step 3: Regenerate config
```bash
SAIA_API_KEY={env:SAIA_API_KEY} SAIA_PROFILE=<chosen-profile> \
  bash ~/.config/pi/plugins/saia/generate-saia-config.sh
```

### Step 4: Copy to pi config
```bash
cp ~/.config/pi/plugins/saia/pi-saia-<chosen-profile>.json ~/.config/pi/plugins/saia/pi-saia.json
```

### Step 5: Restart pi
"Please restart pi for changes to take effect."

## Confirmation
After switching, verify by checking:
- The profile-specific config file exists
- The default model matches the profile
- The model count is appropriate for the profile

## Response Template

```
✓ Switched to <profile> profile

Changes made:
- SAIA_PROFILE set to: <profile>
- Config regenerated: ~/.config/pi/plugins/saia/pi-saia-<profile>.json
- Model count: X models
- Default model: saia/<default-model>

To apply changes: Restart pi
```
