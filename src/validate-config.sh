#!/usr/bin/env bash

# pi Config Validator
# Validates pi.json files against JSON schema to catch configuration errors early

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema/pi.schema.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# Check for required tools
check_dependencies() {
    if ! command -v ajv &> /dev/null && ! command -v jq &> /dev/null; then
        print_error "Neither 'ajv' nor 'jq' found. Install one of:"
        print_info "  - ajv-cli: npm install -g ajv-cli"
        print_info "  - jq: apt install jq (Linux) or brew install jq (macOS)"
        exit 1
    fi
}

# Validate using ajv if available
validate_with_ajv() {
    local config_file="$1"
    if ajv validate -s "$SCHEMA_FILE" -d "$config_file" --strict=0 2>&1; then
        print_success "✓ Configuration file is valid: $config_file"
        return 0
    else
        return 1
    fi
}

# Basic validation using jq
validate_with_jq() {
    local config_file="$1"

    # Check if file is valid JSON
    if ! jq -e '.' "$config_file" > /dev/null 2>&1; then
        print_error "Invalid JSON in $config_file"
        return 1
    fi

    # Basic structure checks
    local errors=()

    if ! jq -e '.provider.saia' "$config_file" > /dev/null 2>&1; then
        errors+=("Missing required field: provider.saia")
    fi

    if ! jq -e '.model' "$config_file" > /dev/null 2>&1; then
        errors+=("Missing required field: model")
    elif ! jq -r '.model' "$config_file" | grep -q '^saia/'; then
        errors+=("Invalid model format: must start with 'saia/'")
    fi

    if ! jq -e '.provider.saia.options.apiKey' "$config_file" > /dev/null 2>&1; then
        errors+=("Missing required field: provider.saia.options.apiKey")
    elif ! jq -r '.provider.saia.options.apiKey' "$config_file" | grep -q 'SAIA_API_KEY'; then
        errors+=("Invalid apiKey format: must reference SAIA_API_KEY env variable")
    fi

    # Check at least one model exists
    local model_count=$(jq -r '.provider.saia.models | length' "$config_file" 2>/dev/null || echo "0")
    if [[ "$model_count" -eq 0 ]]; then
        errors+=("No models configured in provider.saia.models")
    fi

    if [ ${#errors[@]} -gt 0 ]; then
        print_error "Validation errors in $config_file:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi

    print_success "✓ Configuration file is valid: $config_file"
    return 0
}

# Main validation function
validate_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi

    print_info "Validating configuration: $config_file"

    if command -v ajv &> /dev/null; then
        validate_with_ajv "$config_file"
    else
        print_info "Using basic jq validation (install ajv-cli for full schema validation)"
        validate_with_jq "$config_file"
    fi
}

# Print usage and exit
usage() {
    echo "Usage: $0 [options] <config-file>"
    echo ""
    echo "Options:"
    echo "  -s, --schema FILE    Use custom schema file"
    echo "  -h, --help           Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 pi.json"
    echo "  $0 ~/.config/pi/pi.json"
    echo ""
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--schema)
            SCHEMA_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            ;;
        *)
            CONFIG_FILE="$1"
            shift
            ;;
    esac
done

# Validate schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    print_error "Schema file not found: $SCHEMA_FILE"
    exit 1
fi

# Check dependencies
check_dependencies

# Validate configuration if file provided
if [ -z "${CONFIG_FILE:-}" ]; then
    print_error "No configuration file specified"
    usage
else
    validate_config "$CONFIG_FILE"
fi
