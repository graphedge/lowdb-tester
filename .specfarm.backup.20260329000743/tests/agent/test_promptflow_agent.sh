#!/usr/bin/env bash
# Test suite for specfarm.promptflow4speckit agent
# Constitution II.A: Zero-dependency testing with plain bash

set -euo pipefail

# Test result counters
PASSED=0
FAILED=0
TEST_NAME=""

# Helper function: run a test
run_test() {
    TEST_NAME="$1"
    echo "Running: $TEST_NAME"
}

# Helper function: assert equality
assert_equal() {
    local expected="$1"
    local actual="$2"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ PASS: $TEST_NAME"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: $TEST_NAME"
        echo "    Expected: $expected"
        echo "    Actual: $actual"
        FAILED=$((FAILED + 1))
    fi
}

# Helper function: assert contains
assert_contains() {
    local expected="$1"
    local actual="$2"
    
    if echo "$actual" | grep -qF "$expected"; then
        echo "  ✓ PASS: $TEST_NAME"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: $TEST_NAME"
        echo "    Expected substring: $expected"
        echo "    Actual: $actual"
        FAILED=$((FAILED + 1))
    fi
}

# Test agent documentation file
AGENT_FILE=".github/agents/specfarm.promptflow4speckit.agent.md"

echo "=== Promptflow Agent Test Suite ==="
echo ""

# ============================================================================
# T003: Task Parsing Logic Tests
# ============================================================================
echo "--- T003: Task Parsing Logic ---"

run_test "T003-1: Agent documentation mentions single task input"
if grep -q "Single task" "$AGENT_FILE" && grep -q "Multi-line list" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document both single task and multi-line list formats"
    FAILED=$((FAILED + 1))
fi

run_test "T003-2: Agent documentation explains task splitting"
if grep -qi "parse.*task" "$AGENT_FILE" || grep -qi "split.*task" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document task parsing/splitting logic"
    FAILED=$((FAILED + 1))
fi

run_test "T003-3: Agent documentation mentions whitespace handling"
if grep -qi "trim\|whitespace\|empty line" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document whitespace/empty line handling"
    FAILED=$((FAILED + 1))
fi

run_test "T003-4: Agent documentation includes task index tracking"
if grep -qi "task.*index\|task.*[0-9]\|enumerate" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document task index tracking (1-based)"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T004: Agent Selection Heuristic Tests
# ============================================================================
echo "--- T004: Agent Selection Heuristic ---"

run_test "T004-1: Agent documentation lists plan4speckit keywords"
if grep -qi "plan.*design.*architecture" "$AGENT_FILE" || (grep -qi "plan4speckit" "$AGENT_FILE" && grep -qi "keywords" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document plan4speckit selection keywords"
    FAILED=$((FAILED + 1))
fi

run_test "T004-2: Agent documentation lists implement4speckit keywords"
if grep -qi "implement.*fix.*add" "$AGENT_FILE" || (grep -qi "implement4speckit" "$AGENT_FILE" && grep -qi "keywords" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document implement4speckit selection keywords"
    FAILED=$((FAILED + 1))
fi

run_test "T004-3: Agent documentation specifies default agent"
if grep -qi "default.*implement4speckit\|ambiguous.*implement4speckit" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document default to implement4speckit if ambiguous"
    FAILED=$((FAILED + 1))
fi

run_test "T004-4: Agent documentation mentions explicit override"
if grep -qi "override\|prefix.*plan:\|prefix.*implement:" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document explicit prefix override (plan: or implement:)"
    FAILED=$((FAILED + 1))
fi

run_test "T004-5: Agent selection logic includes plan4speckit"
if grep -q "plan4speckit" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must reference plan4speckit agent"
    FAILED=$((FAILED + 1))
fi

run_test "T004-6: Agent selection logic includes implement4speckit"
if grep -q "implement4speckit" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must reference implement4speckit agent"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T005: Static Prompt Template Tests
# ============================================================================
echo "--- T005: Static Prompt Template ---"

run_test "T005-1: Agent documentation includes task description slot"
if grep -qi "\[TASK\]\|\[TASK_DESCRIPTION\]" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document [TASK] or [TASK_DESCRIPTION] slot in template"
    FAILED=$((FAILED + 1))
fi

run_test "T005-2: Agent documentation includes context slot"
if grep -qi "\[CONTEXT\]\|\[GRANULAR_CONTEXT\]" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document [CONTEXT] or [GRANULAR_CONTEXT] slot in template"
    FAILED=$((FAILED + 1))
fi

run_test "T005-3: Agent documentation includes SpecFarm constraints"
if grep -qi "Constraints" "$AGENT_FILE" && grep -qi "Constitution\|Lean Bash\|Pre-commit" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document SpecFarm constraints (Lean Bash, Pre-commit, Constitution)"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T006: Status Reporting Format Tests
# ============================================================================
echo "--- T006: Status Reporting Format ---"

run_test "T006-1: Agent documentation specifies exact status format"
if grep -q "=== Task.*done ===" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document exact status format: === Task N done === [status] [agent]"
    FAILED=$((FAILED + 1))
fi

run_test "T006-2: Agent documentation shows status format example"
if grep -qi "Task 1 done\|Task 2 done" "$AGENT_FILE" || (grep -q "===" "$AGENT_FILE" && grep -qi "example" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must include example of status format"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T007: Graceful Context Gathering Tests (Unit)
# ============================================================================
echo "--- T007: Graceful Context Gathering (Unit) ---"

run_test "T007-1: Agent documentation mentions gather-rules agent call"
if grep -qi "gather-rules\|specfarm.gather-rules" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document gather-rules agent invocation"
    FAILED=$((FAILED + 1))
fi

run_test "T007-2: Agent documentation explains graceful degradation"
if grep -qi "graceful\|unavailable.*continue\|fail.*continue" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document graceful degradation on gather-rules failure"
    FAILED=$((FAILED + 1))
fi

run_test "T007-3: Agent documentation specifies empty context fallback"
if grep -qi "empty.*context\|context.*=.*empty\|context.*=\"\"" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document empty context fallback on failure"
    FAILED=$((FAILED + 1))
fi

run_test "T007-4: Agent documentation mentions timeout for gather-rules"
if grep -qi "timeout.*10\|10.*second\|timeout" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document timeout for gather-rules (10 seconds)"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T011: Additional Unit Tests for Task Parsing (Coverage)
# ============================================================================
echo "--- T011: Task Parsing Coverage Tests ---"

run_test "T011-1: Agent documentation covers single task parsing"
if grep -qi "single task" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must explicitly cover single task input"
    FAILED=$((FAILED + 1))
fi

run_test "T011-2: Agent documentation covers multiple task parsing"
if grep -qi "multi.*line\|multiple.*task\|list.*task" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must explicitly cover multiple task input"
    FAILED=$((FAILED + 1))
fi

run_test "T011-3: Agent documentation covers empty line filtering"
if grep -qi "empty.*line\|skip.*empty" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document empty line filtering"
    FAILED=$((FAILED + 1))
fi

run_test "T011-4: Agent documentation covers whitespace trimming"
if grep -qi "trim\|whitespace" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document whitespace trimming"
    FAILED=$((FAILED + 1))
fi

run_test "T011-5: Agent documentation includes usage examples with multiple tasks"
if grep -qi "example" "$AGENT_FILE" && grep -qE "Task [0-9]" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must include multi-task usage examples"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T012: Additional Unit Tests for Agent Selection (Coverage)
# ============================================================================
echo "--- T012: Agent Selection Coverage Tests ---"

run_test "T012-1: Agent documentation shows plan keyword example"
if grep -qiE "plan.*architecture|design.*schema|plan.*strategy" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show plan keyword examples"
    FAILED=$((FAILED + 1))
fi

run_test "T012-2: Agent documentation shows implement keyword example"
if grep -qiE "implement.*auth|fix.*bug|add.*validation|create.*endpoint" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show implement keyword examples"
    FAILED=$((FAILED + 1))
fi

run_test "T012-3: Agent documentation lists all plan4speckit keywords"
if grep -qiE "plan.*design.*architecture.*spec.*research" "$AGENT_FILE" || (grep -qi "plan4speckit" "$AGENT_FILE" && grep -qi "keywords" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must list all plan4speckit keywords"
    FAILED=$((FAILED + 1))
fi

run_test "T012-4: Agent documentation lists all implement4speckit keywords"
if grep -qiE "implement.*fix.*add.*create.*update.*modify" "$AGENT_FILE" || (grep -qi "implement4speckit" "$AGENT_FILE" && grep -qi "keywords" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must list all implement4speckit keywords"
    FAILED=$((FAILED + 1))
fi

run_test "T012-5: Agent documentation shows explicit override example"
if grep -qE "plan:.*implement:|override.*prefix" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show explicit override examples"
    FAILED=$((FAILED + 1))
fi

run_test "T012-6: Agent documentation confirms default to implement4speckit"
if grep -qiE "default.*implement4speckit|ambiguous.*implement" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must confirm default to implement4speckit"
    FAILED=$((FAILED + 1))
fi

echo ""

# Phase 5 tests will be added here (T011, T012)

echo ""
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total: $((PASSED + FAILED))"

if [[ $FAILED -eq 0 ]]; then
    echo "✓ All tests passed"
    exit 0
else
    echo "✗ $FAILED test(s) failed"
    exit 1
fi
