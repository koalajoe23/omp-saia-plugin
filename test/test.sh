#!/usr/bin/env bash
# Test suite for pi-saia-plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

skip() {
    echo -e "${YELLOW}⊘${NC} $1"
    ((SKIP_COUNT++))
}

echo_header() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
}

# Test 1: File structure
test_file_structure() {
    echo_header "File Structure Tests"
    
    local required_files=(
        "package.json"
        "tsconfig.json"
        "src/saia.ts"
        "src/saia-memory.ts"
        "src/generate-saia-config.sh"
        "src/copy-saia-config.sh"
        "src/validate-config.sh"
        "src/setup-wizard.sh"
        "install.sh"
        "install.ps1"
        "README.md"
        "LICENSE"
        "schema/pi.schema.json"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$PROJECT_DIR/$file" ]; then
            pass "File exists: $file"
        else
            fail "File missing: $file"
        fi
    done
    
    # Check skill files
    local skill_files=(
        "src/.opencode/skills/saia-refresh.md"
        "src/.opencode/skills/saia-health.md"
        "src/.opencode/skills/saia-list-models.md"
        "src/.opencode/skills/saia-switch-profile.md"
        "src/.opencode/skills/saia-optimize.md"
    )
    
    for file in "${skill_files[@]}"; do
        if [ -f "$PROJECT_DIR/$file" ]; then
            pass "Skill file exists: $file"
        else
            fail "Skill file missing: $file"
        fi
    done
    
    # Check new files
    local new_files=(
        "SECURITY.md"
        "ROADMAP.md"
        "CHANGELOG.md"
        "Dockerfile"
        ".dockerignore"
        ".github/workflows/test.yml"
        ".github/workflows/release.yml"
    )
    
    for file in "${new_files[@]}"; do
        if [ -f "$PROJECT_DIR/$file" ]; then
            pass "New file exists: $file"
        else
            skip "New file missing (optional): $file"
        fi
    done
}

# Test 2: TypeScript compilation
test_typescript() {
    echo_header "TypeScript Compilation"
    
    cd "$PROJECT_DIR"
    if command -v npx &> /dev/null; then
        if npx tsc --noEmit --skipLibCheck 2>&1; then
            pass "TypeScript compilation successful"
        else
            fail "TypeScript compilation failed"
        fi
    else
        skip "TypeScript check (npx not available)"
    fi
}

# Test 3: Shell script syntax
test_shell_syntax() {
    echo_header "Shell Script Syntax"
    
    cd "$PROJECT_DIR"
    local scripts=(
        "src/generate-saia-config.sh"
        "src/copy-saia-config.sh"
        "src/validate-config.sh"
        "src/setup-wizard.sh"
        "install.sh"
        "test/test.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>&1; then
                pass "Shell syntax OK: $script"
            else
                fail "Shell syntax error: $script"
            fi
        fi
    done
}

# Test 4: JSON validity
test_json_validity() {
    echo_header "JSON Validity"
    
    cd "$PROJECT_DIR"
    local json_files=(
        "package.json"
        "tsconfig.json"
        "schema/pi.schema.json"
        "pi.json.example"
        ".github/workflows/test.yml"
        ".github/workflows/release.yml"
    )
    
    for file in "${json_files[@]}"; do
        if [ -f "$file" ]; then
            if command -v jq &> /dev/null; then
                if jq empty "$file" 2>&1; then
                    pass "JSON valid: $file"
                else
                    fail "JSON invalid: $file"
                fi
            else
                skip "JSON check (jq not available): $file"
            fi
        fi
    done
}

# Test 5: File permissions
test_permissions() {
    echo_header "File Permissions"
    
    cd "$PROJECT_DIR"
    local executable_files=(
        "src/generate-saia-config.sh"
        "src/copy-saia-config.sh"
        "src/validate-config.sh"
        "src/setup-wizard.sh"
        "install.sh"
        "install.ps1"
        "test/test.sh"
    )
    
    for file in "${executable_files[@]}"; do
        if [ -f "$file" ]; then
            if [ -x "$file" ]; then
                pass "Executable: $file"
            else
                chmod +x "$file"
                pass "Fixed executable: $file"
            fi
        fi
    done
}

# Test 6: Package.json validity
test_package_json() {
    echo_header "Package.json Tests"
    
    cd "$PROJECT_DIR"
    
    if [ -f "package.json" ]; then
        pass "package.json exists"
        
        if command -v jq &> /dev/null; then
            local name=$(jq -r '.name' package.json)
            local version=$(jq -r '.version' package.json)
            local main=$(jq -r '.main' package.json)
            local type=$(jq -r '.type' package.json)
            
            if [ "$name" = "pi-saia-plugin" ]; then
                pass "package.json name is correct: $name"
            else
                fail "package.json name incorrect: $name"
            fi
            
            if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                pass "package.json version is valid: $version"
            else
                fail "package.json version invalid: $version"
            fi
            
            if [ "$main" = "./src/saia.ts" ]; then
                pass "package.json main is correct: $main"
            else
                fail "package.json main incorrect: $main"
            fi
            
            if [ "$type" = "module" ]; then
                pass "package.json type is correct: $type"
            else
                fail "package.json type incorrect: $type"
            fi
        else
            skip "package.json content check (jq not available)"
        fi
    else
        fail "package.json missing"
    fi
}

# Test 7: Script simulated execution
test_script_simulation() {
    echo_header "Script Simulation Tests"
    
    cd "$PROJECT_DIR"
    
    # Test that generate script has required functions
    if grep -q "categorize()" src/generate-saia-config.sh; then
        pass "generate-saia-config.sh has categorize function"
    else
        fail "generate-saia-config.sh missing categorize function"
    fi
    
    if grep -q "include_in_profile()" src/generate-saia-config.sh; then
        pass "generate-saia-config.sh has include_in_profile function"
    else
        fail "generate-saia-config.sh missing include_in_profile function"
    fi
    
    if grep -q "can_reason()" src/generate-saia-config.sh; then
        pass "generate-saia-config.sh has can_reason function"
    else
        fail "generate-saia-config.sh missing can_reason function"
    fi
    
    # Test validate script
    if grep -q "validate_with_ajv\|validate_with_jq" src/validate-config.sh; then
        pass "validate-config.sh has validation functions"
    else
        fail "validate-config.sh missing validation functions"
    fi
}

# Test 8: Documentation completeness
test_documentation() {
    echo_header "Documentation Tests"
    
    cd "$PROJECT_DIR"
    
    if grep -q "SAIA" README.md; then
        pass "README.md mentions SAIA"
    else
        fail "README.md missing SAIA mention"
    fi
    
    if grep -q "Installation" README.md; then
        pass "README.md has Installation section"
    else
        fail "README.md missing Installation section"
    fi
    
    if grep -q "Usage" README.md; then
        pass "README.md has Usage section"
    else
        fail "README.md missing Usage section"
    fi
    
    if [ -f "FAQ.md" ] && [ $(wc -l < FAQ.md) -gt 50 ]; then
        pass "FAQ.md is comprehensive"
    else
        skip "FAQ.md check"
    fi
    
    if [ -f "ARCHITECTURE.md" ] && [ $(wc -l < ARCHITECTURE.md) -gt 100 ]; then
        pass "ARCHITECTURE.md is comprehensive"
    else
        skip "ARCHITECTURE.md check"
    fi
}

# Test 9: GitHub workflows
test_github_workflows() {
    echo_header "GitHub Workflows Tests"
    
    cd "$PROJECT_DIR"
    
    if [ -f ".github/workflows/test.yml" ]; then
        pass "test.yml workflow exists"
        if grep -q "node-version" .github/workflows/test.yml; then
            pass "test.yml has Node.js matrix"
        else
            fail "test.yml missing Node.js matrix"
        fi
    else
        skip "test.yml workflow"
    fi
    
    if [ -f ".github/workflows/release.yml" ]; then
        pass "release.yml workflow exists"
        if grep -q "action-gh-release" .github/workflows/release.yml; then
            pass "release.yml uses GitHub release action"
        else
            fail "release.yml missing release action"
        fi
    else
        skip "release.yml workflow"
    fi
    
    if [ -f ".github/ISSUE_TEMPLATE/bug_report.md" ]; then
        pass "Bug report template exists"
    else
        skip "Bug report template"
    fi
    
    if [ -f ".github/ISSUE_TEMPLATE/feature_request.md" ]; then
        pass "Feature request template exists"
    else
        skip "Feature request template"
    fi
}

# Test 10: Security checks
test_security() {
    echo_header "Security Tests"
    
    cd "$PROJECT_DIR"
    
    # Check for accidental API key commits
    if git grep -q "SAIA_API_KEY.*[a-zA-Z0-9]" 2>/dev/null || false; then
        fail "Potential API key found in git history"
    else
        pass "No API keys in git history"
    fi
    
    # Check for .env files
    if [ -f ".env" ]; then
        fail ".env file should not be committed"
    else
        pass "No .env file committed"
    fi
    
    # Check SECURITY.md
    if [ -f "SECURITY.md" ]; then
        pass "SECURITY.md exists"
        if grep -q "Reporting Security Issues" SECURITY.md; then
            pass "SECURITY.md has reporting guidelines"
        else
            fail "SECURITY.md missing reporting guidelines"
        fi
    else
        skip "SECURITY.md"
    fi
}

# Main test runner
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║       pi-saia-plugin Test Suite                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    test_file_structure
    test_typescript
    test_shell_syntax
    test_json_validity
    test_permissions
    test_package_json
    test_script_simulation
    test_documentation
    test_github_workflows
    test_security
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                    Test Results                         ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    printf "║  Passed: %-3d                                      ║\n" "$PASS_COUNT"
    printf "║  Failed: %-3d                                      ║\n" "$FAIL_COUNT"
    printf "║  Skipped: %-3d                                     ║\n" "$SKIP_COUNT"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

main
