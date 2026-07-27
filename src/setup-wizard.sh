#!/usr/bin/env bash
set -euo pipefail

# SAIA Plugin Interactive Setup Wizard for pi
# Guides first-time users through installation and configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "${BLUE}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓ $1${NC}"; }
print_error() { echo -e "${RED}  ✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}  → $1${NC}"; }
print_prompt() { echo -en "${BLUE}  ? $1${NC} "; }

confirm() {
    local prompt="$1"
    local response
    print_prompt "$prompt (y/n)"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

detect_platform() {
    case "$(uname -s)" in
        Linux*)   echo "linux" ;;
        Darwin*)  echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

detect_shell() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then echo "zsh"
    elif [[ -n "${BASH_VERSION:-}" ]]; then echo "bash"
    else echo "unknown"; fi
}

detect_config_dir() {
    local config_dir="$HOME/.config/pi"
    echo "$config_dir"
}

validate_api_key() {
    local key="$1"
    local result
    result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        "https://chat-ai.academiccloud.de/v1/models" \
        -H "Authorization: Bearer $key")
    [[ "$result" == "200" ]]
}

write_to_shell_rc() {
    local shell_rc="$1"
    local key="$2"
    local export_line="export SAIA_API_KEY=\"$key\""

    if grep -q "SAIA_API_KEY" "$shell_rc" 2>/dev/null; then
        sed -i.bak "s|export SAIA_API_KEY=.*|$export_line|" "$shell_rc"
        print_success "Updated existing SAIA_API_KEY in $shell_rc"
    else
        echo "" >> "$shell_rc"
        echo "# SAIA API key for pi coding agent" >> "$shell_rc"
        echo "$export_line" >> "$shell_rc"
        print_success "Added SAIA_API_KEY to $shell_rc"
    fi
}

run_wizard() {
    clear
    print_header "╔══════════════════════════════════════════════╗"
    print_header "║   SAIA Plugin for pi — Setup Wizard        ║"
    print_header "╚══════════════════════════════════════════════╝"
    echo ""

    local platform=$(detect_platform)
    local shell=$(detect_shell)
    local config_dir=$(detect_config_dir)

    print_info "Detected platform: $platform"
    print_info "Detected shell: $shell"
    print_info "Config directory: $config_dir"
    echo ""

    # Step 1: API Key
    print_header "Step 1/4: SAIA API Key"
    echo ""

    API_KEY=""
    if [[ -n "${SAIA_API_KEY:-}" ]]; then
        print_info "Found SAIA_API_KEY in current environment"

        if validate_api_key "$SAIA_API_KEY"; then
            print_success "API key is valid"
            API_KEY="$SAIA_API_KEY"
        else
            print_error "API key is invalid or expired"
            API_KEY=""
        fi
    fi

    if [[ -z "$API_KEY" ]]; then
        print_info "Get your API key at: https://chat-ai.academiccloud.de"
        print_prompt "Enter your SAIA API key"
        read -r API_KEY

        if [[ -z "$API_KEY" ]]; then
            print_error "No API key provided. Cannot continue."
            exit 1
        fi

        if ! validate_api_key "$API_KEY"; then
            print_error "API key validation failed (network error or invalid key)"
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        else
            print_success "API key validated successfully"
        fi
    fi
    echo ""

    # Step 2: Profile Selection
    print_header "Step 2/4: Profile Selection"
    echo ""
    echo "  1) Production  — Highest quality (glm-4.7, qwen3.5-397b, deepseek-r1)"
    echo "  2) Development — Balanced (qwen3.5-35b, coder models, gemma-4)"
    echo "  3) Budget      — Cheapest/fastest (llama-3.1-8b, gemma-3)"
    echo ""

    print_prompt "Select profile (1/2/3)"
    read -r profile_choice
    case "$profile_choice" in
        1) SELECTED_PROFILE="production" ;;
        2) SELECTED_PROFILE="dev" ;;
        3) SELECTED_PROFILE="budget" ;;
        *) SELECTED_PROFILE="production" ;;
    esac
    print_success "Selected profile: $SELECTED_PROFILE"
    echo ""

    # Step 3: Installation
    print_header "Step 3/4: Installation"
    echo ""

    local plugin_dir="$config_dir/plugins/saia"

    if [[ -d "$plugin_dir" ]]; then
        print_info "Existing installation found at $plugin_dir"
        if confirm "Overwrite existing installation?"; then
            rm -rf "$plugin_dir"
            print_info "Removed old installation"
        else
            print_info "Keeping existing installation"
        fi
    fi

    if [[ ! -d "$plugin_dir" ]]; then
        mkdir -p "$plugin_dir"
        # Use find with nullglob-safe expansion to avoid glob failures
        shopt -s nullglob
        local files=("$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.json "$SCRIPT_DIR"/*.ts)
        shopt -u nullglob
        if [[ ${#files[@]} -gt 0 ]]; then
            cp -r "${files[@]}" "$plugin_dir/" 2>/dev/null || true
        fi
        chmod +x "$plugin_dir"/*.sh 2>/dev/null || true
        print_success "Plugin files installed to $plugin_dir"
    fi
    echo ""

    # Step 4: Configuration
    print_header "Step 4/4: Configuration"
    echo ""

    local pi_config="$config_dir/pi.json"

    if [[ -f "$pi_config" ]]; then
        print_info "Existing pi.json found"
        if confirm "Keep existing config (skip generation)?"; then
            print_info "Skipping config generation"
        else
            SAIA_API_KEY="$API_KEY" SAIA_PROFILE="$SELECTED_PROFILE" \
                bash "$plugin_dir/generate-saia-config.sh"
            print_success "Generated new config with profile: $SELECTED_PROFILE"
        fi
    else
        SAIA_API_KEY="$API_KEY" SAIA_PROFILE="$SELECTED_PROFILE" \
            bash "$plugin_dir/generate-saia-config.sh"
        print_success "Generated config with profile: $SELECTED_PROFILE"
    fi

    # Ensure plugin is registered
    if ! grep -q '"saia"' "$pi_config" 2>/dev/null; then
        print_info "Adding plugin registration to pi.json"
        jq '. + {"plugin": ["saia"]}' "$pi_config" > "${pi_config}.tmp" && mv "${pi_config}.tmp" "$pi_config"
        print_success "Added plugin registration"
    fi

    # Persist API key
    print_info "Persisting API key for future sessions..."
    case "$shell" in
        bash)
            local rc_file="$HOME/.bashrc"
            [[ "$platform" == "macos" ]] && rc_file="$HOME/.bash_profile"
            write_to_shell_rc "$rc_file" "$API_KEY"
            ;;
        zsh)
            write_to_shell_rc "$HOME/.zshrc" "$API_KEY"
            ;;
        *)
            print_info "Add to your shell config: export SAIA_API_KEY=\"$API_KEY\""
            ;;
    esac

    # Final summary
    echo ""
    print_header "╔══════════════════════════════════════════════╗"
    print_header "║            Setup Complete!                  ║"
    print_header "╚══════════════════════════════════════════════╝"
    echo ""
    print_success "API key configured and validated"
    print_success "Profile: $SELECTED_PROFILE"
    print_success "Plugin installed: $plugin_dir"
    print_success "Config: $pi_config"
    echo ""
    print_info "To start using SAIA models with pi:"
    print_info "  1. Restart your shell (or run: source ~/.bashrc)"
    print_info "  2. Start pi in any project directory"
    echo ""
    print_info "Switch models with: /model saia/<model-name>"
    print_info "Use aliases:       /model saia/best-for-coding"
    print_info "Change profile:     SAIA_PROFILE=dev bash src/generate-saia-config.sh"
    echo ""
}

run_wizard
