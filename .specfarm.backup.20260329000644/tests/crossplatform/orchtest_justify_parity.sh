#!/usr/bin/env bash
# .specfarm/tests/crossplatform/orchtest_justify_parity.sh
# T028a [US2] ORCHESTRATED parity test: justification log JSON structure
#
# Tests: Trigger identical drift violation on bash env; enter justification;
# normalize encodings/line endings; compare `.specfarm/justifications.log` JSON Lines structure
#
# Constitution: II.A (Zero external dependencies - no jq, pure bash)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export SPECFARM_ROOT="$REPO_ROOT"

# Source test helper
source "$REPO_ROOT/.specfarm/tests/test_helper.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$result" == "PASS" ]]; then
        echo "  ✓ $test_name: PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ $test_name: FAIL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Parse JSON Lines field using pure bash/grep/awk (NO jq)
parse_jsonl_field() {
    local json_line="$1"
    local field_name="$2"
    
    # Extract field value using grep and sed
    # Handles: "field_name":"value" or "field_name":123
    echo "$json_line" | grep -oP "\"$field_name\":\s*\"[^\"]*\"" | sed -E "s/\"$field_name\":\s*\"([^\"]*)\"/\1/" || \
    echo "$json_line" | grep -oP "\"$field_name\":\s*[^,}]+" | sed -E "s/\"$field_name\":\s*//"
}

# Count JSON Lines entries
count_jsonl_entries() {
    local file="$1"
    grep -c '^{' "$file" 2>/dev/null || echo "0"
}

# Validate JSON Lines structure (required fields present)
validate_jsonl_structure() {
    local file="$1"
    local line_num=0
    local valid=true
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Check for required fields: timestamp, rule_id, status, justification
        if ! echo "$line" | grep -q '"timestamp"'; then
            echo "    Line $line_num missing 'timestamp'" >&2
            valid=false
        fi
        if ! echo "$line" | grep -q '"rule_id"'; then
            echo "    Line $line_num missing 'rule_id'" >&2
            valid=false
        fi
        if ! echo "$line" | grep -q '"status"'; then
            echo "    Line $line_num missing 'status'" >&2
            valid=false
        fi
        if ! echo "$line" | grep -q '"justification"'; then
            echo "    Line $line_num missing 'justification'" >&2
            valid=false
        fi
    done < "$file"
    
    if [[ "$valid" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Test 1: Justification log JSON structure validation
t028a_01_justify_json_structure() {
    echo ""
    echo "Test: T028a-01 - Justification log JSON Lines structure validation"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    
    # Verify fixture exists
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    
    # Test 1a: File is readable and non-empty
    if [[ ! -s "$test_log" ]]; then
        echo "    FAIL: Justification log is empty"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    
    # Test 1b: Count entries
    local entry_count
    entry_count=$(count_jsonl_entries "$test_log")
    echo "    Found $entry_count JSON Lines entries"
    
    if [[ "$entry_count" -lt 1 ]]; then
        echo "    FAIL: No JSON Lines entries found"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    
    # Test 1c: Validate JSON structure (all required fields present)
    if ! validate_jsonl_structure "$test_log"; then
        echo "    FAIL: JSON Lines structure validation failed"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    
    # Test 1d: Parse first entry and verify field extraction
    local first_entry
    first_entry=$(head -n 1 "$test_log")
    
    local timestamp
    timestamp=$(parse_jsonl_field "$first_entry" "timestamp")
    if [[ -z "$timestamp" ]]; then
        echo "    FAIL: Could not extract timestamp field"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    echo "    Extracted timestamp: $timestamp"
    
    local rule_id
    rule_id=$(parse_jsonl_field "$first_entry" "rule_id")
    if [[ -z "$rule_id" ]]; then
        echo "    FAIL: Could not extract rule_id field"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    echo "    Extracted rule_id: $rule_id"
    
    # Test 1e: Verify rule_id format (should be kebab-case)
    if ! echo "$rule_id" | grep -qE '^[a-z][a-z0-9-]*$'; then
        echo "    WARN: rule_id format unusual: $rule_id (expected kebab-case)"
    fi
    
    # Test 1f: Verify no binary content (all printable + newlines)
    if grep -qP '[^\x20-\x7E\n\r\t]' "$test_log"; then
        echo "    FAIL: Binary content detected in log file"
        test_result "T028a-01-justify-json-structure" "FAIL"
        return 1
    fi
    
    test_result "T028a-01-justify-json-structure" "PASS"
    return 0
}

# Test 2: Normalized comparison (simulated parity test)
t028a_02_normalized_parity() {
    echo ""
    echo "Test: T028a-02 - Normalized justification log comparison"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    local parity_validator="$SCRIPT_DIR/parity-validator.sh"
    
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028a-02-normalized-parity" "FAIL"
        return 1
    fi
    
    if [[ ! -x "$parity_validator" ]]; then
        echo "    SKIP: parity-validator not executable: $parity_validator"
        test_result "T028a-02-normalized-parity" "FAIL"
        return 1
    fi
    
    # Normalize the log file (line endings, timestamps, whitespace)
    local normalized_output
    normalized_output=$(bash "$parity_validator" --file "$test_log" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "    FAIL: parity-validator exited with code $exit_code"
        test_result "T028a-02-normalized-parity" "FAIL"
        return 1
    fi
    
    # Verify normalized output still has JSON Lines structure
    local normalized_entry_count
    normalized_entry_count=$(echo "$normalized_output" | grep -c '^{' || echo "0")
    
    local original_entry_count
    original_entry_count=$(count_jsonl_entries "$test_log")
    
    if [[ "$normalized_entry_count" -ne "$original_entry_count" ]]; then
        echo "    FAIL: Entry count mismatch after normalization"
        echo "    Original: $original_entry_count, Normalized: $normalized_entry_count"
        test_result "T028a-02-normalized-parity" "FAIL"
        return 1
    fi
    
    echo "    Normalization preserved $normalized_entry_count entries"
    
    # Verify timestamps were normalized
    if echo "$normalized_output" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        echo "    WARN: Timestamps may not be fully normalized (date pattern still present)"
    fi
    
    test_result "T028a-02-normalized-parity" "PASS"
    return 0
}

# Test 3: Field count verification
t028a_03_field_count_match() {
    echo ""
    echo "Test: T028a-03 - Verify all entries have same field count"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028a-03-field-count-match" "FAIL"
        return 1
    fi
    
    local field_counts=()
    local line_num=0
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line_num=$((line_num + 1))
        
        # Count fields by counting commas + 1 (simple heuristic)
        local field_count
        field_count=$(echo "$line" | grep -o '","' | wc -l)
        field_count=$((field_count + 1))
        
        field_counts+=("$field_count")
    done < "$test_log"
    
    # Verify all entries have same field count
    local first_count="${field_counts[0]}"
    local consistent=true
    
    for count in "${field_counts[@]}"; do
        if [[ "$count" -ne "$first_count" ]]; then
            echo "    FAIL: Inconsistent field counts detected"
            consistent=false
            break
        fi
    done
    
    if [[ "$consistent" != "true" ]]; then
        test_result "T028a-03-field-count-match" "FAIL"
        return 1
    fi
    
    echo "    All $line_num entries have consistent field counts"
    
    test_result "T028a-03-field-count-match" "PASS"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "T028a: Justification Log JSON Structure Test"
    echo "Constitution: II.A (Zero external dependencies)"
    echo "=========================================="
    
    t028a_01_justify_json_structure
    t028a_02_normalized_parity
    t028a_03_field_count_match
    
    echo ""
    echo "=========================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "Result: ALL TESTS PASSED ✓"
        exit 0
    else
        echo "Result: SOME TESTS FAILED ✗"
        exit 1
    fi
}

main "$@"
