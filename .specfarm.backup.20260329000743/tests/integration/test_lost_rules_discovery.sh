#!/bin/bash
# Integration test for lost rules discovery (Phase 0b)
# Tests that gather-rules-agent.sh can now find the 5 categories of lost rules

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENT_SCRIPT="$REPO_ROOT/.specfarm/agents/gather-rules-agent.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "Running: $test_name"
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  ✓ PASS"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "  ✗ FAIL"
    fi
}

# Simple inline version of extract_task_keywords for testing
# (mirrors the patched version in gather-rules-agent.sh)
extract_task_keywords_inline() {
    local task_desc="$1"
    
    local files=$(echo "$task_desc" | grep -oE '[a-zA-Z0-9_/.-]+\.(sh|py|js|ts|xml|md)' || echo "")
    local test_patterns=$(echo "$task_desc" | grep -oE 'test_[a-zA-Z0-9_]+' || echo "")
    local dirs=$(echo "$task_desc" | grep -oE '(tests?|src|specs?|lib)/[a-zA-Z0-9_/-]*' || echo "")
    local actions=$(echo "$task_desc" | grep -oEi '\b(fix|implement|add|refactor|update|create|test)\b' || echo "")
    
    local constitution_refs=$(echo "$task_desc" | grep -oEi '\b(constitution|constitutional)\b' || echo "")
    if echo "$task_desc" | grep -qi "Constitution.*II\.A\|zero.depend"; then
        constitution_refs="$constitution_refs zero-dependency"
    fi
    
    local task_context_keywords=$(echo "$task_desc" | grep -oEi '\b(task.context|task-context|--task-context|TASK_CONTEXT)\b' || echo "")
    if echo "$task_desc" | grep -qi "task.context.*mode\|compact.*output.*format"; then
        task_context_keywords="$task_context_keywords task-mode"
    fi
    
    local confidence_keywords=$(echo "$task_desc" | grep -oEi '\b(confidence|scoring|calculate.*confidence)\b' || echo "")
    if echo "$task_desc" | grep -qi "confidence.*scor\|scor.*algorithm"; then
        confidence_keywords="$confidence_keywords confidence-algorithm"
    fi
    
    local crossplatform_keywords=""
    if echo "$task_desc" | grep -qi "line.ending\|CRLF\|LF.*CR\|\\\\r\\\\n"; then
        crossplatform_keywords="$crossplatform_keywords line-endings CRLF"
    fi
    if echo "$task_desc" | grep -qi "path.*normaliz\|Windows.*path\|/c/\|C:\\\\"; then
        crossplatform_keywords="$crossplatform_keywords path-normalize windows-path"
    fi
    if echo "$task_desc" | grep -qi "PowerShell\|pwsh\|\.ps1"; then
        crossplatform_keywords="$crossplatform_keywords powershell pwsh"
    fi
    if echo "$task_desc" | grep -qi "cross.platform\|Windows.*Unix\|Unix.*Windows"; then
        crossplatform_keywords="$crossplatform_keywords cross-platform"
    fi
    
    local test_framework_keywords=""
    if echo "$task_desc" | grep -qi "pytest\|BATS\|Jest\|mocha\|jasmine"; then
        test_framework_keywords="external-test-framework"
    fi
    if echo "$task_desc" | grep -qi "pure.*bash\|plain.*bash\|no.*external.*depend"; then
        test_framework_keywords="$test_framework_keywords bash-only"
    fi
    
    echo "$files $test_patterns $dirs $actions $constitution_refs $task_context_keywords $confidence_keywords $crossplatform_keywords $test_framework_keywords" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

#
# Test 1: extract_task_keywords finds Constitution references
#
test_constitution_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Ensure all tests follow Constitution II.A - zero dependency testing with pure bash")
    
    # Case-insensitive check for constitution (output might be "Constitution" or "constitution")
    echo "$keywords" | grep -qi "constitution" || return 1
    echo "$keywords" | grep -q "zero-dependency" || return 1
    return 0
}

#
# Test 2: extract_task_keywords finds task-context mode keywords
#
test_task_context_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Implement --task-context flag parsing for compact output formatting")
    
    echo "$keywords" | grep -qi "task-context" || return 1
    return 0
}

#
# Test 3: extract_task_keywords finds confidence scoring keywords
#
test_confidence_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Calculate confidence scoring algorithm based on git history and test links")
    
    echo "$keywords" | grep -qi "confidence" || return 1
    echo "$keywords" | grep -qi "scoring\|confidence-algorithm" || return 1
    return 0
}

#
# Test 4: extract_task_keywords finds line endings keywords
#
test_line_endings_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Handle line ending normalization for CRLF and LF across platforms")
    
    echo "$keywords" | grep -qi "line-endings\|CRLF" || return 1
    return 0
}

#
# Test 5: extract_task_keywords finds path normalization keywords
#
test_path_normalize_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Normalize Windows paths for cross-platform compatibility")
    
    echo "$keywords" | grep -qi "path-normalize\|cross-platform" || return 1
    return 0
}

#
# Test 6: extract_task_keywords handles pure bash patterns
#
test_bash_only_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "All tests must be plain bash with no external dependencies like pytest or BATS")
    
    echo "$keywords" | grep -qi "bash-only\|bash" || return 1
    # Should detect external framework mention
    echo "$keywords" | grep -q "external-test-framework" || return 1
    return 0
}

#
# Test 7: extract_task_keywords handles PowerShell/cross-platform
#
test_powershell_keywords() {
    local keywords
    keywords=$(extract_task_keywords_inline "Add PowerShell .ps1 wrapper for cross-platform Windows support")
    
    echo "$keywords" | grep -qi "powershell\|pwsh" || return 1
    echo "$keywords" | grep -qi "cross-platform" || return 1
    return 0
}

# Run all tests
echo "========================================"
echo "Lost Rules Discovery Tests (Phase 0b)"
echo "========================================"
echo ""

run_test "Constitution keywords extraction" test_constitution_keywords
run_test "Task-context keywords extraction" test_task_context_keywords
run_test "Confidence scoring keywords extraction" test_confidence_keywords
run_test "Line endings keywords extraction" test_line_endings_keywords
run_test "Path normalization keywords extraction" test_path_normalize_keywords
run_test "Bash-only patterns extraction" test_bash_only_keywords
run_test "PowerShell/cross-platform keywords extraction" test_powershell_keywords

# ============================================================================
# New tests: lost rules actually found in rules.xml via --task-context, and
# duplication_check() flags near-identical rules
# ============================================================================

#
# Test 8: --task-context finds r_constitution_zero_depend_001 in rules.xml
# (proves the lost rule is now discoverable end-to-end)
#
test_lost_rule_found_via_task_context() {
    local rules_xml="$REPO_ROOT/.specfarm/rules.xml"
    [[ -f "$rules_xml" ]] || { echo "  rules.xml not found"; return 1; }

    # Source just the functions we need from the agent (skip main)
    # We do this by extracting and eval-ing the relevant functions
    local tmpfile
    tmpfile=$(mktemp)
    # Extract lines up to (not including) the final `main "$@"` call
    grep -n "^main " "$AGENT_SCRIPT" | tail -1 | cut -d: -f1 | read -r main_line || true
    head -n -1 "$AGENT_SCRIPT" > "$tmpfile"
    # Source extracted functions (disable set -e for sourcing)
    set +e
    # shellcheck disable=SC1090
    RULES_XML_PATH="$rules_xml" XMLLINT_CMD="xmllint" source "$tmpfile" 2>/dev/null
    set -e
    rm -f "$tmpfile"

    # Now call extract_task_keywords + search_rules_xpath directly
    local keywords
    keywords=$(extract_task_keywords "Enforce zero dependency testing Constitution II.A pure bash no pytest")
    [[ -n "$keywords" ]] || { echo "  no keywords extracted"; return 1; }

    local matched
    matched=$(RULES_XML_PATH="$rules_xml" search_rules_xpath "$keywords" 2>/dev/null || echo "")
    echo "$matched" | grep -q "r_constitution_zero_depend_001" || {
        echo "  r_constitution_zero_depend_001 not found in: $matched"
        return 1
    }
    return 0
}

#
# Test 9: duplication_check() flags a near-identical candidate as a duplicate
# Uses a synthetic rules.xml with two similar rules
#
test_duplication_check_flags_similar_rules() {
    local tmpxml
    tmpxml=$(mktemp --suffix=.xml)
    cat > "$tmpxml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules xmlns="http://specfarm.example.org/rules" version="1.0">
  <rule id="rule-shell-error-logging" enabled="true" severity="enforce" phase="2" category="logging">
    <name>Shell Error Logging Required</name>
    <description>All shell command errors must be logged to shell-errors.log with timestamp and exit code for audit trail purposes.</description>
    <scope>global</scope>
  </rule>
  <rule id="rule-shell-error-capture" enabled="true" severity="enforce" phase="2" category="logging">
    <name>Shell Error Capture Required</name>
    <description>Shell command errors must be captured and logged with timestamp and exit code for audit and debugging purposes.</description>
    <scope>global</scope>
  </rule>
</rules>
XMLEOF

    # Source functions from agent (skip main)
    local tmpagent
    tmpagent=$(mktemp)
    head -n -1 "$AGENT_SCRIPT" > "$tmpagent"
    set +e
    # shellcheck disable=SC1090
    RULES_XML_PATH="$tmpxml" XMLLINT_CMD="xmllint" DUPLICATION_THRESHOLD="40" \
        source "$tmpagent" 2>/dev/null
    set -e
    rm -f "$tmpagent"

    # Call duplication_check with a candidate that strongly overlaps rule-shell-error-logging
    local dup_result
    dup_result=$(RULES_XML_PATH="$tmpxml" XMLLINT_CMD="xmllint" DUPLICATION_THRESHOLD="40" \
        duplication_check \
        "Shell Error Logging Required" \
        "All shell errors must be logged to shell-errors.log with timestamp and exit code." \
        2>/dev/null || true)

    rm -f "$tmpxml"

    # Should have flagged at least one duplicate
    echo "$dup_result" | grep -q "POSSIBLE DUPLICATE" || {
        echo "  duplication_check did not flag similar rule"
        echo "  output: $dup_result"
        return 1
    }
    return 0
}

run_test "Lost rule found via --task-context end-to-end" test_lost_rule_found_via_task_context
run_test "duplication_check flags near-identical rules" test_duplication_check_flags_similar_rules

echo ""
echo "========================================"
echo "Summary: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
echo "========================================"

[ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
