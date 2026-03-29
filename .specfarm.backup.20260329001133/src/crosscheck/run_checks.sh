#!/usr/bin/env bash
# T032 [P] [US3] Simple rule cross-check runner
# Runs basic checks on specseed files and produces a score report
set -euo pipefail

# Usage function
usage() {
    cat <<EOF
Usage: run_checks.sh --specseed <path>

Run cross-checks on a specseed directory and generate a score report.

Options:
  --specseed PATH    Path to specseed directory (required)
  --help, -h         Show this help message

EOF
}

# Parse arguments
SPECSEED_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --specseed)
            SPECSEED_PATH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SPECSEED_PATH" ]]; then
    echo "Error: --specseed is required" >&2
    usage
    exit 1
fi

if [[ ! -d "$SPECSEED_PATH" ]]; then
    echo "Error: Specseed path does not exist: $SPECSEED_PATH" >&2
    exit 1
fi

# Initialize results
TOTAL_CHECKS=0
PASSED_CHECKS=0
REPORT_FILE="$SPECSEED_PATH/crosscheck-report.txt"

# Helper function to record check result
record_check() {
    local check_name="$1"
    local result="$2"  # "PASS" or "FAIL"
    local details="${3:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ "$result" == "PASS" ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo "✓ PASS: $check_name"
        echo "✓ PASS: $check_name" >> "$REPORT_FILE"
    else
        echo "✗ FAIL: $check_name${details:+ - $details}"
        echo "✗ FAIL: $check_name${details:+ - $details}" >> "$REPORT_FILE"
    fi
}

# Start report
echo "=== CrossCheck Report ===" | tee "$REPORT_FILE"
echo "Specseed: $SPECSEED_PATH" | tee -a "$REPORT_FILE"
echo "Date: $(date +%Y-%m-%d\ %H:%M:%S)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Check 1: spec.md file exists
if [[ -f "$SPECSEED_PATH/spec.md" ]]; then
    record_check "spec.md exists" "PASS"
else
    record_check "spec.md exists" "FAIL" "file not found"
fi

# Check 2: Required sections present (## Goals)
if [[ -f "$SPECSEED_PATH/spec.md" ]]; then
    if grep -q "^## Goals" "$SPECSEED_PATH/spec.md"; then
        record_check "Required section: ## Goals" "PASS"
    else
        record_check "Required section: ## Goals" "FAIL" "section not found"
    fi
    
    # Check 3: Required sections present (## Constraints)
    if grep -q "^## Constraints" "$SPECSEED_PATH/spec.md"; then
        record_check "Required section: ## Constraints" "PASS"
    else
        record_check "Required section: ## Constraints" "FAIL" "section not found"
    fi
    
    # Check 4: Word count > 50
    WORD_COUNT=$(wc -w < "$SPECSEED_PATH/spec.md")
    if [[ $WORD_COUNT -gt 50 ]]; then
        record_check "Word count > 50 (found: $WORD_COUNT)" "PASS"
    else
        record_check "Word count > 50 (found: $WORD_COUNT)" "FAIL" "insufficient content"
    fi
else
    # Skip remaining checks if spec.md doesn't exist
    record_check "Required section: ## Goals" "FAIL" "spec.md not found"
    record_check "Required section: ## Constraints" "FAIL" "spec.md not found"
    record_check "Word count > 50" "FAIL" "spec.md not found"
fi

# Calculate score
echo "" | tee -a "$REPORT_FILE"
echo "=== Summary ===" | tee -a "$REPORT_FILE"
echo "SCORE: $PASSED_CHECKS/$TOTAL_CHECKS" | tee -a "$REPORT_FILE"

if [[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]]; then
    echo "Status: ALL CHECKS PASSED" | tee -a "$REPORT_FILE"
    exit 0
else
    echo "Status: SOME CHECKS FAILED" | tee -a "$REPORT_FILE"
    exit 0  # Non-blocking: exit 0 even on failures (this is a quality check, not a hard validation)
fi
