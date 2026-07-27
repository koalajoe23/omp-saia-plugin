#!/bin/bash
set -e

# Prepare release script for pi-saia-plugin
# Validates, generates, and packages the plugin for release

VERSION=$(node -p "require('./package.json').version")
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

print_header() {
    echo ""
    echo "=========================================="
    echo "  pi-saia-plugin v$VERSION Release Prep"
    echo "=========================================="
    echo ""
}

print_step() {
    echo "  → $1"
}

print_success() {
    echo "  ✓ $1"
}

print_error() {
    echo "  ✗ $1"
    exit 1
}

# Validate package.json
validate_package() {
    print_step "Validating package.json..."
    if [ ! -f "package.json" ]; then
        print_error "package.json not found"
    fi
    
    # Check required fields
    if ! grep -q '"name": "pi-saia-plugin"' package.json; then
        print_error "package.json missing name field"
    fi
    
    if ! grep -q '"version"' package.json; then
        print_error "package.json missing version field"
    fi
    
    print_success "package.json is valid"
}

# Validate TypeScript files
validate_typescript() {
    print_step "Validating TypeScript files..."
    
    if [ ! -f "tsconfig.json" ]; then
        print_error "tsconfig.json not found"
    fi
    
    if [ ! -f "src/saia.ts" ]; then
        print_error "src/saia.ts not found"
    fi
    
    if [ ! -f "src/saia-memory.ts" ]; then
        print_error "src/saia-memory.ts not found"
    fi
    
    # Try to compile (no emit)
    if command -v npx &> /dev/null; then
        if npx tsc --noEmit --skipLibCheck 2>&1; then
            print_success "TypeScript files are valid"
        else
            print_error "TypeScript compilation failed"
        fi
    else
        print_success "TypeScript files exist (skipping compilation check)"
    fi
}

# Validate shell scripts
validate_scripts() {
    print_step "Validating shell scripts..."
    
    local scripts=(
        "src/generate-saia-config.sh"
        "src/copy-saia-config.sh"
        "src/validate-config.sh"
        "src/setup-wizard.sh"
        "install.sh"
        "install.ps1"
    )
    
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            print_error "$script not found"
        fi
        if [ ${script: -3} == ".sh" ]; then
            # Check for bash shebang
            if ! head -1 "$script" | grep -q "#!/bin/bash\|#!/usr/bin/env bash"; then
                print_error "$script missing bash shebang"
            fi
            # Check for execute permission
            if [ ! -x "$script" ]; then
                chmod +x "$script"
            fi
        fi
    done
    
    print_success "Shell scripts are valid"
}

# Validate schema files
validate_schemas() {
    print_step "Validating schema files..."
    
    if [ ! -f "schema/pi.schema.json" ]; then
        print_error "schema/pi.schema.json not found"
    fi
    
    # Validate JSON
    if command -v jq &> /dev/null; then
        if ! jq empty schema/pi.schema.json 2>&1; then
            print_error "schema/pi.schema.json is invalid JSON"
        fi
    fi
    
    print_success "Schema files are valid"
}

# Validate documentation
validate_docs() {
    print_step "Validating documentation..."
    
    local docs=(
        "README.md"
        "FAQ.md"
        "ARCHITECTURE.md"
        "LICENSE"
    )
    
    for doc in "${docs[@]}"; do
        if [ ! -f "$doc" ]; then
            print_error "$doc not found"
        fi
    done
    
    print_success "Documentation files are present"
}

# Validate skills
validate_skills() {
    print_step "Validating skill files..."
    
    local skills_dir="src/.opencode/skills"
    if [ ! -d "$skills_dir" ]; then
        print_error "$skills_dir not found"
    fi
    
    local expected_skills=(
        "saia-refresh.md"
        "saia-health.md"
        "saia-list-models.md"
        "saia-switch-profile.md"
        "saia-optimize.md"
    )
    
    for skill in "${expected_skills[@]}"; do
        if [ ! -f "$skills_dir/$skill" ]; then
            print_error "$skills_dir/$skill not found"
        fi
    done
    
    print_success "Skill files are present"
}

# Test generation
validate_generation() {
    print_step "Testing configuration generation..."
    
    if [ -z "${SAIA_API_KEY:-}" ]; then
        print_step "  (skipping - SAIA_API_KEY not set)"
        return
    fi
    
    # Test with a temporary directory
    local tmp_dir=$(mktemp -d)
    pushd "$tmp_dir" > /dev/null 2>&1
    
    if bash "$(dirname "$0")/../src/generate-saia-config.sh" 2>&1; then
        if [ -f "pi-saia.json" ]; then
            local model_count=$(jq -r '.provider.saia.models | length' pi-saia.json 2>/dev/null || echo "0")
            if [ "$model_count" -gt 0 ]; then
                print_success "Generation successful ($model_count models)"
            else
                print_error "No models generated"
            fi
        else
            print_error "pi-saia.json not created"
        fi
    else
        print_error "Generation failed"
    fi
    
    popd > /dev/null 2>&1
    rm -rf "$tmp_dir"
}

# Cleanup
cleanup() {
    print_step "Cleaning up old files..."
    
    # Remove old generated files
    rm -f src/pi-saia.json src/pi-saia-*.json
    
    print_success "Cleanup complete"
}

# Main
main() {
    print_header
    
    print_step "Starting release preparation..."
    echo ""
    
    validate_package
    validate_typescript
    validate_scripts
    validate_schemas
    validate_docs
    validate_skills
    validate_generation
    cleanup
    
    echo ""
    echo "=========================================="
    echo "  Release Preparation Complete!"
    echo "=========================================="
    echo ""
    echo "Version: v$VERSION"
    echo "Commit: $GIT_HASH"
    echo ""
    echo "Next steps:"
    echo "  1. Review changes: git diff"
    echo "  2. Commit changes: git commit -m 'Prepare v$VERSION'"
    echo "  3. Create tag: git tag v$VERSION"
    echo "  4. Push to remote: git push && git push --tags"
    echo ""
}

main
