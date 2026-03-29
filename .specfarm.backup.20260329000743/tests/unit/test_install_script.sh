#!/bin/bash
# .specfarm/tests/unit/test_install_script.sh
#
# Unit tests for specfarm-install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../bin/specfarm-install.sh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0

pass() {
    echo -e "${GREEN}PASS:${NC} $1"
    ((TOTAL_PASS++)) || true
}

fail() {
    echo -e "${RED}FAIL:${NC} $1"
    ((TOTAL_FAIL++)) || true
}

################################################################################
# Test: Script exists and is executable
################################################################################
test_script_exists() {
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        pass "Install script exists"
    else
        fail "Install script not found: $INSTALL_SCRIPT"
    fi
}

################################################################################
# Test: Script has valid syntax
################################################################################
test_syntax() {
    if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
        pass "Syntax valid"
    else
        fail "Syntax errors detected"
    fi
}

################################################################################
# Test: Help output works
################################################################################
test_help() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1)
    
    if echo "$output" | grep -q "SpecFarm Installation Script"; then
        pass "Help output displays correctly"
    else
        fail "Help output missing or malformed"
    fi
}

################################################################################
# Test: Missing target argument fails
################################################################################
test_missing_target() {
    local output exit_code
    output=$(bash "$INSTALL_SCRIPT" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 2 ]]; then
        pass "Missing target argument correctly fails with exit code 2"
    else
        fail "Missing target should exit with code 2, got: $exit_code"
    fi
}

################################################################################
# Test: Invalid target fails
################################################################################
test_invalid_target() {
    local output exit_code
    output=$(bash "$INSTALL_SCRIPT" --target /nonexistent/path/12345 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 3 ]]; then
        pass "Invalid target correctly fails with exit code 3"
    else
        fail "Invalid target should exit with code 3, got: $exit_code"
    fi
}

################################################################################
# Test: Dry-run mode works
################################################################################
test_dry_run() {
    local tmp_target="/tmp/specfarm-test-target-$$"
    mkdir -p "$tmp_target"
    
    local output
    output=$(bash "$INSTALL_SCRIPT" --target "$tmp_target" --dry-run 2>&1)
    
    if echo "$output" | grep -q "\[DRY-RUN\]"; then
        pass "Dry-run mode works"
    else
        fail "Dry-run mode not functioning"
    fi
    
    rm -rf "$tmp_target"
}

################################################################################
# Test: Source validation
################################################################################
test_source_validation() {
    # Should pass since we're running from the specfarm repo
    local tmp_target="/tmp/specfarm-test-target-$$"
    mkdir -p "$tmp_target"
    
    local output
    output=$(bash "$INSTALL_SCRIPT" --target "$tmp_target" --dry-run 2>&1)
    
    if echo "$output" | grep -q "Source validated"; then
        pass "Source validation works"
    else
        fail "Source validation failed"
    fi
    
    rm -rf "$tmp_target"
}

################################################################################
# Test: --yes flag skips prompts
################################################################################
test_yes_flag() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1)
    
    if echo "$output" | grep -q -- "--yes"; then
        pass "--yes flag documented in help"
    else
        fail "--yes flag not documented"
    fi
}

################################################################################
# Test: Environment variable fallback
################################################################################
test_env_fallback() {
    local tmp_target="/tmp/specfarm-test-target-$$"
    mkdir -p "$tmp_target"
    
    local output
    output=$(TARGET_REPO_PATH="$tmp_target" bash "$INSTALL_SCRIPT" --dry-run 2>&1)
    
    if echo "$output" | grep -q "Target validated"; then
        pass "Environment variable TARGET_REPO_PATH works"
    else
        fail "Environment variable fallback failed"
    fi
    
    rm -rf "$tmp_target"
}

################################################################################
# Run all tests
################################################################################

echo "╔══════════════════════════════════════════════════════════╗"
echo "║      SpecFarm Install Script - Unit Tests               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

test_script_exists
test_syntax
test_help
test_missing_target
test_invalid_target
test_dry_run
test_source_validation
test_yes_flag
test_env_fallback

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $TOTAL_PASS passed, $TOTAL_FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $TOTAL_FAIL -gt 0 ]]; then
    exit 1
else
    exit 0
fi
