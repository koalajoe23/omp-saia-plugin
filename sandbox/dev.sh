#!/usr/bin/env bash
# SAIA Plugin Sandbox - Development Environment
# Run this script to start a development container with volume mounting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
IMAGE_NAME="ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest-dev"
CONTAINER_NAME="saia-dev"
HOST_APP_DIR="$PROJECT_DIR"

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

show_help() {
    cat << EOF
SAIA Plugin Development Sandbox

Usage: $(basename "$0") [OPTIONS]

Options:
  -p, --pull      Pull latest development image before running
  -n, --name NAME Set container name (default: $CONTAINER_NAME)
  -h, --help      Show this help message

Environment Variables:
  SAIA_API_KEY    Your GWDG Chat AI API key (required for API calls)
  SAIA_PROFILE    Model profile: production, development, budget
  LITELLM_PROXY_URL Optional LiteLLM proxy URL

Examples:
  $(basename "$0")                          # Start development container
  SAIA_API_KEY=your_key $(basename "$0")    # With API key
  $(basename "$0") -p                       # Pull latest dev image

The development sandbox mounts your local project directory into the container,
allowing you to edit files on your host and see changes immediately in the container.

Changes made inside the container to /home/pluginuser/app will affect your local files.

EOF
    exit 0
}

# Parse arguments
PULL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pull)
            PULL=true
            shift
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if the image exists locally
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo_info "Image not found locally. Pulling from registry..."
    PULL=true
fi

# Pull if requested
if $PULL; then
    echo_info "Pulling development image..."
    docker pull "$IMAGE_NAME" 2>&1 | grep -E "(Downloaded|Pulling|Status|Image is up to date)" || true
fi

# Check if container already exists
if docker ps -a -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo_warning "Container '$CONTAINER_NAME' already exists."
    read -rp "Remove and recreate? [y/N] " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Removing existing container..."
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    else
        echo_info "Using existing container."
    fi
fi

# Stop any running container with the same name
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo_info "Stopping existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
fi

# Start the development container
DOCKER_OPTS=(
    "run"
    "-it"
    "-d"
    "--name" "$CONTAINER_NAME"
    "-e" "SAIA_API_KEY=${SAIA_API_KEY:-}"
    "-e" "SAIA_PROFILE=${SAIA_PROFILE:-development}"
    "-e" "LITELLM_PROXY_URL=${LITELLM_PROXY_URL:-}"
    "-v" "$HOST_APP_DIR:/home/pluginuser/app"
    "-v" "saia-config-vol:/home/pluginuser/.config/pi"
    "-v" "saia-cache-vol:/home/pluginuser/.cache/saia"
    "-w" "/home/pluginuser/app"
    "-p" "8080:8080"  # For local API testing
)

# Add gpus if available (for AI workloads)
if command -v nvidia-smi &> /dev/null; then
    DOCKER_OPTS+=("--gpus" "all")
fi

DOCKER_OPTS+=("$IMAGE_NAME")
DOCKER_OPTS+=("tail -f /dev/null")

DOCKER_CMD="${DOCKER_OPTS[*]}"

echo_info "Starting development container..."
echo_info "Image: $IMAGE_NAME"
echo_info "Container: $CONTAINER_NAME"
echo_info "App directory: $HOST_APP_DIR"
echo_info "Config directory: /home/pluginuser/.config/pi (persistent volume)"
echo_info "Cache directory: /home/pluginuser/.cache/saia (persistent volume)"
echo ""

if ! docker "${DOCKER_OPTS[@]}" > /dev/null 2>&1; then
    echo_error "Failed to start container"
    exit 1
fi

echo_success "Development container started: $CONTAINER_NAME"
echo ""

# Wait for container to be ready
sleep 1

echo_info "Attaching to container..."
echo_info "Type 'exit' or press Ctrl+D to detach (container will keep running)"
echo_info ""
echo_info "Useful commands:"
echo_info "  docker exec -it $CONTAINER_NAME bash    # Open new shell"
echo_info "  docker stop $CONTAINER_NAME             # Stop container"
echo_info "  docker rm -f $CONTAINER_NAME            # Remove container"
echo_info "  docker logs $CONTAINER_NAME             # View logs"
echo_info ""

# Attach to the container
docker exec -it "$CONTAINER_NAME" bash 2>/dev/null || {
    echo_error "Failed to attach to container"
    exit 1
}

# If we get here, the user has exited the shell
# Check if container is still running and offer to stop it
echo ""
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    read -rp "Detached from container. Stop it now? [y/N] " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Stopping container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        echo_success "Container stopped"
    else
        echo_info "Container is still running. Use 'docker stop $CONTAINER_NAME' to stop it."
    fi
fi
