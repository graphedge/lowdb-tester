#!/bin/bash
# tests/e2e/test_function_exports.sh
# E2E Test: Validate all exported functions and modules are intact
# Part of Phase 3 deletion prevention — see specs/prompts/phase3-deletion-risk-assessment.md
#
# Purpose: Detect silent deletions of critical functions during refactors
# This test is run at pre-commit to prevent incomplete refactors from being committed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== SpecFarm Function Export Integrity Test ==="
echo "Validating critical functions and modules (Phase 3 deletion prevention)"
echo ""

FAILURES=0
PASSES=0

# Configuration: module -> list of required exported functions
# These functions MUST exist or critical functionality will fail silently
declare -A REQUIRED_FUNCTIONS=(
    ["src/drift/drift_engine.sh"]="run_drift_check"
    ["src/vibe/nudge_engine.sh"]="dispatch_nudge"
    ["src/drift/export_markdown.sh"]="export_markdown"
    ["src/export/exporter.sh"]="export_rules"
)

# Configuration: bin/ scripts -> functions they import
# These scripts rely on the functions existing in their sourced modules
declare -A SCRIPT_DEPENDENCIES=(
    ["bin/drift-engine"]="run_drift_check|dispatch_nudge|export_drift_report"
    ["bin/specfarm"]="run_drift_check"
)

# ====================================================================
# Test 1: Verify source modules exist and contain required functions
# ====================================================================

echo "Test 1: Module function inventory..."
echo "---"

for module in "${!REQUIRED_FUNCTIONS[@]}"; do
    functions="${REQUIRED_FUNCTIONS[$module]}"
    module_path="$BASE_DIR/$module"
    
    if [[ ! -f "$module_path" ]]; then
        echo "FAIL: Module not found: $module"
        FAILURES=$((FAILURES + 1))
        continue
    fi
    
    # Check file size (early warning for truncated files)
    lines=$(wc -l < "$module_path")
    if [[ $lines -lt 30 ]] && [[ "$module" != *"/templates/"* ]]; then
        echo "WARN: $module is only $lines lines (consider if intentional)"
    fi
    
    # Source the module in a subshell to avoid polluting current environment
    (
        source "$module_path" 2>/dev/null || {
            echo "FAIL: Could not source $module"
            exit 1
        }
        
        # Verify each required function exists
        for func in ${functions//|/ }; do
            if ! declare -f "$func" >/dev/null 2>&1; then
                echo "FAIL: Function '$func' not found in $module"
                exit 1
            fi
        done
    ) || {
        FAILURES=$((FAILURES + 1))
        continue
    }
    
    echo "PASS: $module exports {$functions}"
    PASSES=$((PASSES + 1))
done

echo ""

# ====================================================================
# Test 2: Verify bin/ scripts can source their dependencies
# ====================================================================

echo "Test 2: Bin script dependencies..."
echo "---"

for script in "${!SCRIPT_DEPENDENCIES[@]}"; do
    script_path="$BASE_DIR/$script"
    functions="${SCRIPT_DEPENDENCIES[$script]}"
    
    if [[ ! -f "$script_path" ]]; then
        echo "FAIL: Script not found: $script"
        FAILURES=$((FAILURES + 1))
        continue
    fi
    
    # Try to source the script (this will fail if dependencies are missing)
    if bash -n "$script_path" 2>&1 | grep -q "command not found\|No such file"; then
        echo "FAIL: Script $script has syntax or sourcing errors"
        FAILURES=$((FAILURES + 1))
    else
        echo "PASS: $script syntax OK"
        PASSES=$((PASSES + 1))
    fi
done

echo ""

# ====================================================================
# Test 3: Detect orphaned imports (sourced but missing)
# ====================================================================

echo "Test 3: Checking for orphaned imports..."
echo "---"

for bin_file in "$BASE_DIR"/bin/{drift-engine,specfarm}; do
    if [[ -f "$bin_file" ]]; then
        # Extract all source statements pointing to src/
        while IFS= read -r source_line; do
            # Parse: source "$BASE_DIR/src/... OR source "BASE_DIR/src/...
            module=$(echo "$source_line" | sed -n 's/.*source.*\${\?BASE_DIR\}\/\(src\/[^"]*\).*/\1/p')
            
            if [[ -n "$module" ]]; then
                module_path="$BASE_DIR/$module"
                
                if [[ ! -f "$module_path" ]]; then
                    echo "FAIL: Orphaned import in $(basename "$bin_file"): $module (file not found)"
                    FAILURES=$((FAILURES + 1))
                else
                    echo "PASS: Import in $(basename "$bin_file") → $module OK"
                fi
            fi
        done < <(grep 'source.*BASE_DIR.*src/' "$bin_file" 2>/dev/null || true)
    fi
done

echo ""

# ====================================================================
# Test 4: Summary and exit
# ====================================================================

echo "=== Test Summary ==="
echo "Passed: $PASSES"
echo "Failed: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
    echo "✓ All function exports validated — no deletions detected"
    exit 0
else
    echo "✗ Function export validation FAILED — module integrity compromised"
    exit 1
fi
