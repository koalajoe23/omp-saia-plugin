#!/bin/bash
set -e

if [ -z "$SAIA_API_KEY" ]; then
  echo "Error: SAIA_API_KEY is not set."
  echo "Get your key from https://chat-ai.academiccloud.de/ then run:"
  echo "  export SAIA_API_KEY=your_key_here"
  exit 1
fi

# PI config directory
PI_CONFIG_DIR="${HOME}/.config/pi"
PLUGIN_DIR="${PI_CONFIG_DIR}/plugins/saia"

# Create directories
mkdir -p "$PLUGIN_DIR"

# Copy plugin files
cp -r src/* "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR"/*.sh 2>/dev/null || true

# Create pi.json if it doesn't exist
PI_CONFIG="${PI_CONFIG_DIR}/pi.json"
if [ ! -f "$PI_CONFIG" ]; then
  mkdir -p "$(dirname "$PI_CONFIG")"
  cat > "$PI_CONFIG" <<'EOF'
{
  "$schema": "https://pi.code/config.json",
  "plugin": ["saia"]
}
EOF
   echo "✓ Created $PI_CONFIG with plugin registration"
 else
   echo "⚠ Config exists at $PI_CONFIG"
   echo "  Add 'plugin' registration if not already present:"
   echo '  "plugin": ["saia"]'
 fi

echo ""
echo "✓ Plugin installed to $PLUGIN_DIR"
echo "  pi will automatically load SAIA models on startup"
echo ""
echo "To test: run pi and use /model saia/<model-name>"
echo "Example: /model saia/glm-4.7"
