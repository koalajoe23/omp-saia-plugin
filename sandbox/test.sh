#!/usr/bin/env bash
# SAIA Plugin Sandbox - Test Runner
# Run the plugin test suite inside the sandbox

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

echo_pass() { 
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

echo_fail() { 
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

echo_skip() { 
    echo -e "${YELLOW}⊘${NC} $1"
    ((SKIP_COUNT++))
}

echo_header() { 
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

show_summary() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗"
    echo "║              Sandbox Test Results                     ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    printf "║  Passed: %-3d                                      ║\n" "$PASS_COUNT"
    printf "║  Failed: %-3d                                      ║\n" "$FAIL_COUNT"
    printf "║  Skipped: %-3d                                     ║\n" "$SKIP_COUNT"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}All sandbox tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some sandbox tests failed.${NC}"
        return 1
    fi
}

# Test functions
test_docker_image() {
    echo_header "Docker Image Tests"

    # Check if image exists
    if docker image inspect "$1" &> /dev/null; then
        echo_pass "Image $1 exists"
    else
        echo_fail "Image $1 not found"
        return 1
    fi

    # Check image size
    SIZE=$(docker image inspect --format='{{.Size}}' "$1")
    SIZE_MB=$((SIZE / 1024 / 1024))
    echo_pass "Image size: ${SIZE_MB}MB"

    # Check creation date
    CREATED=$(docker image inspect --format='{{.Created}}' "$1")
    echo_pass "Created: $CREATED"
}

test_container_basics() {
    echo_header "Container Basics Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Check if container started
    if docker ps -q -f name="$container_name" | grep -q .; then
        echo_pass "Container started successfully"
    else
        echo_fail "Container failed to start"
        docker rm -f "$container_name" 2>/dev/null || true
        return 1
    fi

    # Check running processes
    PROCS=$(docker exec "$container_name" ps aux | wc -l)
    echo_pass "Processes running: $PROCS"

    # Check environment variables
    if docker exec "$container_name" bash -c "echo \$SAIA_PROFILE" 2>/dev/null | grep -q production; then
        echo_pass "SAIA_PROFILE environment variable set"
    fi

    # Check working directory
    PWD=$(docker exec "$container_name" pwd)
    echo_pass "Working directory: $PWD"

    # Check user
    USER=$(docker exec "$container_name" whoami)
    echo_pass "Running as user: $USER"

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

test_dependencies() {
    echo_header "Dependencies Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Test essential commands
    local commands=(
        "node --version"
        "npm --version"
        "curl --version"
        "jq --version"
        "bash --version"
        "git --version"
        "bc --version"
    )

    for cmd in "${commands[@]}"; do
        if docker exec "$container_name" sh -c "$cmd" &> /dev/null; then
            local name=$(echo "$cmd" | cut -d' ' -f1)
            local version=$(docker exec "$container_name" sh -c "$cmd 2>&1" | head -1 | tr -d '\n')
            echo_pass "$name: $version"
        else
            echo_fail "$cmd not available"
        fi
    done

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

test_filesystem() {
    echo_header "Filesystem Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Check essential directories
    local dirs=(
        "/home/pluginuser"
        "/home/pluginuser/app"
        "/home/pluginuser/app/src"
        "/home/pluginuser/app/schema"
        "/home/pluginuser/.config/pi"
        "/home/pluginuser/.config/pi/plugins/saia"
        "/home/pluginuser/.cache/saia"
    )

    for dir in "${dirs[@]}"; do
        if docker exec "$container_name" test -d "$dir" 2>/dev/null; then
            echo_pass "Directory exists: $dir"
        else
            echo_fail "Directory missing: $dir"
        fi
    done

    # Check essential files
    local files=(
        "/home/pluginuser/app/package.json"
        "/home/pluginuser/app/tsconfig.json"
        "/home/pluginuser/app/src/saia.ts"
        "/home/pluginuser/app/src/saia-memory.ts"
        "/home/pluginuser/app/src/generate-saia-config.sh"
        "/home/pluginuser/app/schema/pi.schema.json"
    )

    for file in "${files[@]}"; do
        if docker exec "$container_name" test -f "$file" 2>/dev/null; then
            echo_pass "File exists: $file"
        else
            echo_fail "File missing: $file"
        fi
    done

    # Check permissions
    local scripts=(
        "/home/pluginuser/app/src/generate-saia-config.sh"
        "/home/pluginuser/app/src/copy-saia-config.sh"
        "/home/pluginuser/app/src/validate-config.sh"
        "/home/pluginuser/app/src/setup-wizard.sh"
    )

    for script in "${scripts[@]}"; do
        if docker exec "$container_name" test -x "$script" 2>/dev/null; then
            echo_pass "Script executable: $script"
        else
            echo_fail "Script not executable: $script"
        fi
    done

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

test_typechecking() {
    echo_header "TypeScript Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Check if TypeScript is available (in dev image)
    if docker exec "$container_name" sh -c "command -v npx" &> /dev/null; then
        # Try to run TypeScript check
        local result
        result=$(docker exec "$container_name" bash -c "cd /home/pluginuser/app && npx tsc --noEmit --skipLibCheck 2>&1" | head -5)
        
        if echo "$result" | grep -qi "error TS"; then
            echo_fail "TypeScript errors found"
            echo "  $result"
        else
            echo_pass "TypeScript compilation check passed"
        fi
    else
        echo_skip "TypeScript not available in production image"
    fi

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

test_shell_scripts() {
    echo_header "Shell Script Syntax Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Test shell script syntax
    local scripts=(
        "src/generate-saia-config.sh"
        "src/copy-saia-config.sh"
        "src/validate-config.sh"
        "src/setup-wizard.sh"
        "install.sh"
    )

    for script in "${scripts[@]}"; do
        if docker exec "$container_name" bash -n "/home/pluginuser/app/$script" 2>/dev/null; then
            echo_pass "Shell syntax OK: $script"
        else
            echo_fail "Shell syntax error: $script"
        fi
    done

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

test_json_validation() {
    echo_header "JSON Validation Tests"

    local container_name="saia-test-"$RANDOM

    # Start a temporary container
    docker run -d --name "$container_name" "$1" tail -f /dev/null > /dev/null 2>&1 || true

    # Test JSON files
    local jsons=(
        "package.json"
        "tsconfig.json"
        "schema/pi.schema.json"
    )

    for json in "${jsons[@]}"; do
        if docker exec "$container_name" jq empty "/home/pluginuser/app/$json" 2>/dev/null; then
            echo_pass "JSON valid: $json"
        else
            echo_fail "JSON invalid: $json"
        fi
    done

    # Cleanup
    docker rm -f "$container_name" 2>/dev/null || true
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗"
    echo "║         SAIA Plugin Sandbox Test Suite                 ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    local image="ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest"
    local dev_image="ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest-dev"
    local project_root="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"

    # Build images if they don't exist locally
    if ! docker image inspect "$image" &>/dev/null; then
        echo_info "Building production image..."
        docker build -t "$image" "$project_root" 2>&1 || {
            echo_error "Failed to build production image"
            exit 1
        }
    fi

    if ! docker image inspect "$dev_image" &>/dev/null; then
        echo_info "Building development image..."
        docker build --target builder -t "$dev_image" "$project_root" 2>&1 || {
            echo_warning "Failed to build dev image, tests may be limited"
        }
    fi

    # Check if specific test is requested
    local specific_test="${1:-}"

    if [[ -z "$specific_test" || "$specific_test" == "all" ]]; then
        # Run all tests
        test_docker_image "$image"
        test_container_basics "$image"
        test_dependencies "$image"
        test_filesystem "$image"
        test_shell_scripts "$image"
        test_json_validation "$image"
        test_typechecking "$dev_image"
    elif [[ "$specific_test" == "typescript" ]]; then
        test_typechecking "$dev_image"
    elif [[ "$specific_test" == "shell" ]]; then
        test_shell_scripts "$image"
    elif [[ "$specific_test" == "json" ]]; then
        test_json_validation "$image"
    elif [[ "$specific_test" == "filesystem" ]]; then
        test_filesystem "$image"
    elif [[ "$specific_test" == "dependencies" ]]; then
        test_dependencies "$image"
    else
        echo_error "Unknown test: $specific_test"
        echo "Usage: $0 [all|typescript|shell|json|filesystem|dependencies]"
        exit 1
    fi

    show_summary
}

main "$@"
