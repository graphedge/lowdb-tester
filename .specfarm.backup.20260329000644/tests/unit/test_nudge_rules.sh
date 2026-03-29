#!/bin/bash
# Unit test: verify nudge rule structure and parsing (T008)
# Tests that rules/nudges/*.conf files are valid and parseable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# rules/ lives at the repo root (one level above .specfarm/)
REPO_ROOT="$(cd "$BASE_DIR/.." && pwd)"

NUDGE_RULES_DIR="$REPO_ROOT/rules/nudges"
PASS=0
FAIL=0

assert_pass() {
    local desc="$1"
    echo "PASS: $desc"
    PASS=$((PASS + 1))
}

assert_fail() {
    local desc="$1"
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
}

# Test 1: nudge rules directory exists
if [[ -d "$NUDGE_RULES_DIR" ]]; then
    assert_pass "nudge rules directory exists at $NUDGE_RULES_DIR"
else
    assert_fail "nudge rules directory not found at $NUDGE_RULES_DIR"
fi

# Test 2: at least one .conf file exists
conf_count=$(find "$NUDGE_RULES_DIR" -name "*.conf" 2>/dev/null | wc -l)
if [[ "$conf_count" -gt 0 ]]; then
    assert_pass "at least one nudge rule file found ($conf_count)"
else
    assert_fail "no .conf files found in $NUDGE_RULES_DIR"
fi

# Test 3: each rule file has valid 3-column pipe-delimited format
for rule_file in "$NUDGE_RULES_DIR"/*.conf; do
    [[ -f "$rule_file" ]] || continue
    invalid=0
    lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        [[ -z "$line" || "$line" == \#* ]] && continue
        IFS='|' read -r rule_id pattern message <<< "$line"
        if [[ -z "$rule_id" || -z "$pattern" || -z "$message" ]]; then
            echo "  BAD FORMAT at line $lineno in $(basename "$rule_file"): '$line'"
            invalid=$((invalid + 1))
        fi
    done < "$rule_file"
    if [[ "$invalid" -eq 0 ]]; then
        assert_pass "$(basename "$rule_file") has valid rule format"
    else
        assert_fail "$(basename "$rule_file") has $invalid malformed lines"
    fi
done

# Test 4: known anti-pattern rules are present
expected_rules=("docker-no-cache" "http-not-https" "curl-no-fail")
for rule_id in "${expected_rules[@]}"; do
    found=false
    for rule_file in "$NUDGE_RULES_DIR"/*.conf; do
        [[ -f "$rule_file" ]] || continue
        if grep -q "^${rule_id}|" "$rule_file"; then
            found=true
            break
        fi
    done
    if [[ "$found" == "true" ]]; then
        assert_pass "nudge rule '$rule_id' is defined"
    else
        assert_fail "nudge rule '$rule_id' not found in any .conf file"
    fi
done

# Test 5: patterns in rules are valid regexes (should not cause grep errors)
for rule_file in "$NUDGE_RULES_DIR"/*.conf; do
    [[ -f "$rule_file" ]] || continue
    while IFS='|' read -r rule_id pattern message; do
        [[ -z "$rule_id" || "$rule_id" == \#* ]] && continue
        # grep -E returns exit code 2 on a regex error; 0 or 1 are both acceptable
        exit_code=0
        echo "" | grep -E "$pattern" >/dev/null 2>&1 || exit_code=$?
        if [[ "$exit_code" -eq 2 ]]; then
            assert_fail "pattern '$pattern' in rule '$rule_id' is not a valid regex"
        fi
    done < "$rule_file"
done
assert_pass "all nudge rule patterns are valid regexes"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
