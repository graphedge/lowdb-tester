#!/bin/bash
# .specfarm/tests/integration/test_install_integration.sh
#
# Integration tests for specfarm-install.sh (end-to-end)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../bin/specfarm-install.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
# Test: Fresh installation to empty directory
################################################################################
test_fresh_install() {
    local test_dir="/tmp/specfarm-integration-test-$$"
    mkdir -p "$test_dir"

    # Run install (--skip-tests avoids recursive full suite run)
    local output exit_code=0
    output=$(bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        if [[ -d "$test_dir/.specfarm" ]]; then
            pass "Fresh installation created .specfarm/"
        else
            fail "Fresh installation did not create .specfarm/"
        fi

        if [[ -d "$test_dir/.specfarm/bin" && -d "$test_dir/.specfarm/src" && -d "$test_dir/.specfarm/tests" ]]; then
            pass "Key subdirectories created: bin, src, tests"
        else
            fail "Missing key subdirectories"
        fi

        if [[ -f "$test_dir/.specfarm/bin/specfarm" && -f "$test_dir/.specfarm/bin/drift-engine" ]]; then
            pass "Entrypoint scripts copied"
        else
            fail "Entrypoint scripts missing"
        fi
    else
        fail "Installation failed with unexpected exit code: $exit_code (output: $output)"
    fi

    rm -rf "$test_dir"
}

################################################################################
# Test: Update existing installation
################################################################################
test_update_existing() {
    local test_dir="/tmp/specfarm-integration-update-$$"
    mkdir -p "$test_dir/.specfarm"
    echo "old content" > "$test_dir/.specfarm/test-marker.txt"

    local output exit_code=0
    output=$(bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local backups
        backups=$(ls -d "$test_dir/.specfarm.backup."* 2>/dev/null | wc -l)

        if [[ $backups -gt 0 ]]; then
            pass "Update created backup of existing installation"
        else
            fail "Update did not create backup"
        fi

        if [[ -d "$test_dir/.specfarm/bin" ]]; then
            pass "Update replaced .specfarm/ content"
        else
            fail "Update did not replace content"
        fi
    else
        fail "Update failed with unexpected exit code: $exit_code"
    fi

    rm -rf "$test_dir"
}

################################################################################
# Test: Dry-run does not modify target
################################################################################
test_dry_run_no_modify() {
    local test_dir="/tmp/specfarm-integration-dryrun-$$"
    mkdir -p "$test_dir"
    echo "marker" > "$test_dir/marker.txt"
    
    # Run dry-run
    bash "$INSTALL_SCRIPT" --target "$test_dir" --dry-run >/dev/null 2>&1
    
    # Check that nothing was created
    if [[ ! -d "$test_dir/.specfarm" ]]; then
        pass "Dry-run did not create .specfarm/"
    else
        fail "Dry-run modified target (should not)"
    fi
    
    # Check marker still exists
    if [[ -f "$test_dir/marker.txt" ]]; then
        pass "Dry-run did not modify existing files"
    else
        fail "Dry-run removed files"
    fi
    
    rm -rf "$test_dir"
}

################################################################################
# Test: No changes detection
################################################################################
test_no_changes() {
    local test_dir="/tmp/specfarm-integration-nochanges-$$"
    mkdir -p "$test_dir"

    # First install
    bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests >/dev/null 2>&1

    # Second install (should detect no changes)
    local output
    output=$(bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests 2>&1)

    if echo "$output" | grep -q "up-to-date"; then
        pass "Detected no changes on second install"
    else
        fail "Did not detect unchanged installation"
    fi

    rm -rf "$test_dir"
}

################################################################################
# Test: Agents directory installation
################################################################################
test_agents_install() {
    local test_dir="/tmp/specfarm-integration-agents-$$"
    mkdir -p "$test_dir"

    bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests >/dev/null 2>&1

    if [[ -d "$REPO_ROOT/.github/agents" ]]; then
        if [[ -d "$test_dir/.github/agents" ]]; then
            pass "Agent definitions installed to .github/agents/"
        else
            fail "Agent definitions not installed"
        fi
    else
        pass "No agents directory in source (skipped, OK)"
    fi

    rm -rf "$test_dir"
}

################################################################################
# Test: Permissions preserved
################################################################################
test_permissions() {
    local test_dir="/tmp/specfarm-integration-perms-$$"
    mkdir -p "$test_dir"

    bash "$INSTALL_SCRIPT" --target "$test_dir" --yes --skip-tests >/dev/null 2>&1

    if [[ -x "$test_dir/.specfarm/bin/specfarm" ]]; then
        pass "Executable permissions preserved for scripts"
    else
        fail "Executable permissions not preserved"
    fi

    rm -rf "$test_dir"
}

################################################################################
# Run all tests
################################################################################

echo "╔══════════════════════════════════════════════════════════╗"
echo "║      SpecFarm Install Script - Integration Tests        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

test_fresh_install
test_update_existing
test_dry_run_no_modify
test_no_changes
test_agents_install
test_permissions

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $TOTAL_PASS passed, $TOTAL_FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $TOTAL_FAIL -gt 0 ]]; then
    exit 1
else
    exit 0
fi
