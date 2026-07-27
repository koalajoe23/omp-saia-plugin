#!/usr/bin/env bash
# SAIA Plugin Sandbox - Quick Launcher
# Run this script to start an interactive sandbox environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
IMAGE_NAME="ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest"
IMAGE_DEV="ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest-dev"
CONTAINER_NAME="saia-sandbox"
WORKSPACE="$(pwd)/saia-sandbox-workspace"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_info() { echo -e "${BLUE}→${NC} $1"; }
echo_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1"; }

# Parse arguments
USE_DEV=false
PULL=false
KEEP=false
HELP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dev)
            USE_DEV=true
            shift
            ;;
        -p|--pull)
            PULL=true
            shift
            ;;
        -k|--keep)
            KEEP=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

# Show help
show_help() {
    cat << EOF
SAIA Plugin Sandbox Launcher

Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --dev       Use development image with build tools
  -p, --pull      Pull latest image before running
  -k, --keep      Keep container after exit (use docker rm to clean)
  -h, --help      Show this help message

Environment Variables:
  SAIA_API_KEY    Your GWDG Chat AI API key (required)
  SAIA_PROFILE    Model profile: production, development, budget
  LITELLM_PROXY_URL Optional LiteLLM proxy URL

Examples:
  $(basename "$0")                          # Run with production image
  SAIA_API_KEY=your_key $(basename "$0")    # With API key
  $(basename "$0") -d                       # Development mode
  $(basename "$0") -p -d                    # Pull and use dev image

The sandbox provides an isolated environment for testing the SAIA plugin
without affecting your local setup. All dependencies are pre-installed.

EOF
    exit 0
}

if $HELP || [[ $# -gt 0 ]] && [[ "$1" == "help" ]]; then
    show_help
fi

# Check for SAIA_API_KEY if running interactively
if [[ -z "${SAIA_API_KEY:-}" ]] && [[ "$KEEP" = false ]]; then
    echo_warning "SAIA_API_KEY not set. Some features may not work."
    echo_info "Get your API key at: https://chat-ai.academiccloud.de"
fi

# Select image
if $USE_DEV; then
    SELECTED_IMAGE="$IMAGE_DEV"
    echo_info "Using development image: $SELECTED_IMAGE"
else
    SELECTED_IMAGE="$IMAGE_NAME"
    echo_info "Using production image: $SELECTED_IMAGE"
fi

# Pull image if requested
if $PULL; then
    echo_info "Pulling latest image..."
    docker pull "$SELECTED_IMAGE" 2>&1 | grep -E "(Downloaded|Pulling|Status|Image is up to date)" || true
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Create workspace directory
mkdir -p "$WORKSPACE"
echo_info "Workspace: $WORKSPACE"

# Run the container
DOCKER_OPTS=(
    "run"
    "-it"
)

if ! $KEEP; then
    DOCKER_OPTS+=("--rm")
fi

DOCKER_OPTS+=(
    "--name" "$CONTAINER_NAME"
    "-e" "SAIA_API_KEY=${SAIA_API_KEY:-}"
    "-e" "SAIA_PROFILE=${SAIA_PROFILE:-production}"
    "-e" "LITELLM_PROXY_URL=${LITELLM_PROXY_URL:-}"
    "-v" "$PROJECT_DIR:/home/pluginuser/app:ro"
    "-v" "$WORKSPACE:/workspace"
    "-w" "/workspace"
)

# Add final command
DOCKER_OPTS+=("$SELECTED_IMAGE")

if [[ $# -gt 0 ]]; then
    DOCKER_OPTS+=("$@")
else
    DOCKER_OPTS+=("sh")
fi

echo_info "Starting sandbox container..."
echo ""
echo_info "Type 'exit' to quit the sandbox."
echo_info "Your workspace files are in: $WORKSPACE"
echo ""

# Execute docker command
docker "${DOCKER_OPTS[@]}" 2>&1 || true

# Cleanup hint if keeping container
if $KEEP; then
    echo ""
    echo_info "Container kept. To remove it later:"
    echo_info "  docker rm -f $CONTAINER_NAME"
fi
