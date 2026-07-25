#!/usr/bin/env bash
set -euo pipefail

# SAIA Configuration Copier for pi
# Copies the master SAIA configuration to the current directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_CONFIG="$SCRIPT_DIR/pi-saia.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if master config exists
if [[ ! -f "$MASTER_CONFIG" ]]; then
    print_error "Master configuration not found at: $MASTER_CONFIG"
    print_info "Run generate-saia-config.sh first to create the master configuration"
    exit 1
fi

# Get model count from master config
MODEL_COUNT=$(jq -r '.provider.saia.models | length' "$MASTER_CONFIG" 2>/dev/null || echo "0")
print_info "Master configuration has $MODEL_COUNT SAIA models"

# Copy to current directory as pi.json
cp "$MASTER_CONFIG" ./pi.json
print_info "Copied pi.json to current directory"
print_info "SAIA models are now available in this directory for pi!"
