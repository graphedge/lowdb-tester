#!/usr/bin/env bash
# Integration tests for promptflow agent orchestration
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

# Helper function: assert success
assert_success() {
    local exit_code="$1"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "  ✓ PASS: $TEST_NAME"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: $TEST_NAME (exit code: $exit_code)"
        FAILED=$((FAILED + 1))
    fi
}

# Test agent documentation file
AGENT_FILE=".github/agents/specfarm.promptflow4speckit.agent.md"

echo "=== Agent Orchestration Integration Tests ==="
echo ""

# ============================================================================
# T007: Graceful Context Gathering Tests (Integration)
# ============================================================================
echo "--- T007: Graceful Context Gathering (Integration) ---"

run_test "T007-INT-1: Agent error handling mentions graceful degradation"
if grep -qi "graceful.*degradation\|do not halt\|continue.*failure" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document graceful degradation error handling"
    FAILED=$((FAILED + 1))
fi

run_test "T007-INT-2: Agent documentation distinguishes gather-rules failures from dispatch failures"
if grep -qi "gather-rules.*fail\|context.*fail" "$AGENT_FILE" && grep -qi "circuit.*breaker\|dispatch.*fail" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must distinguish graceful (gather-rules) vs critical (dispatch) failures"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T008: Sequential Task Processing Loop Tests (Integration)
# ============================================================================
echo "--- T008: Sequential Task Processing Loop (Integration) ---"

run_test "T008-INT-1: Agent documentation describes sequential processing"
if grep -qi "sequential\|one at a time\|no.*parallel" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document sequential task processing (no parallelization)"
    FAILED=$((FAILED + 1))
fi

run_test "T008-INT-2: Agent documentation explains processing pipeline"
if grep -qi "parse.*context.*prompt.*dispatch\|workflow\|pipeline" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document processing pipeline steps"
    FAILED=$((FAILED + 1))
fi

run_test "T008-INT-3: Agent documentation mentions EACH task pattern"
if grep -qi "for each\|EACH task\|each task" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document 'for EACH task' processing pattern"
    FAILED=$((FAILED + 1))
fi

run_test "T008-INT-4: Agent documentation shows loop structure"
if grep -qi "Step 1\|Step 2\|Step 3\|enumerate" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show structured loop with steps"
    FAILED=$((FAILED + 1))
fi

run_test "T008-INT-5: Agent documentation includes status reporting per task"
if grep -qi "report.*status\|status.*each\|after.*task" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document status reporting after each task"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T009: Coding Agent Dispatch Tests (Integration)
# ============================================================================
echo "--- T009: Coding Agent Dispatch (Integration) ---"

run_test "T009-INT-1: Agent documentation mentions dispatch to coding agents"
if grep -qi "dispatch\|call.*agent\|invoke.*agent" "$AGENT_FILE" && (grep -qi "plan4speckit\|implement4speckit" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document dispatch to coding agents (plan4speckit or implement4speckit)"
    FAILED=$((FAILED + 1))
fi

run_test "T009-INT-2: Agent documentation mentions waiting for completion"
if grep -qi "wait.*completion\|complete.*before\|synchronous" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document waiting for coding agent completion before next task"
    FAILED=$((FAILED + 1))
fi

run_test "T009-INT-3: Agent documentation mentions task tool usage"
if grep -qi "task.*tool\|use.*task\|via.*task" "$AGENT_FILE" || grep -q "task tool" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document task tool usage for dispatch"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T010: Circuit Breaker Tests (Integration)
# ============================================================================
echo "--- T010: Circuit Breaker (Integration) ---"

run_test "T010-INT-1: Agent documentation describes circuit breaker logic"
if grep -qi "circuit.*breaker\|consecutive.*failure" "$AGENT_FILE" && grep -qi "3.*failure\|three.*failure" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document circuit breaker with 3 consecutive failures threshold"
    FAILED=$((FAILED + 1))
fi

run_test "T010-INT-2: Agent documentation shows circuit breaker reset on success"
if grep -qi "reset.*failure\|failure.*0\|success.*reset" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must document failure counter reset on successful dispatch"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T013: Integration Tests for Graceful Degradation
# ============================================================================
echo "--- T013: Graceful Degradation Integration Tests ---"

run_test "T013-INT-1: Agent documentation describes behavior when gather-rules unavailable"
if grep -qiE "unavailable.*continue|gather-rules.*unavailable|gather-rules.*fail.*continue" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must describe behavior when gather-rules unavailable"
    FAILED=$((FAILED + 1))
fi

run_test "T013-INT-2: Agent documentation describes timeout handling"
if grep -qiE "timeout.*10|10.*second.*timeout" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must describe 10-second timeout for gather-rules"
    FAILED=$((FAILED + 1))
fi

run_test "T013-INT-3: Agent documentation describes error handling with warning log"
if grep -qiE "warning.*stderr|log.*warning|⚠" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must describe warning log to stderr on gather-rules failure"
    FAILED=$((FAILED + 1))
fi

echo ""

# ============================================================================
# T014: Integration Tests for End-to-End Orchestration
# ============================================================================
echo "--- T014: End-to-End Orchestration Integration Tests ---"

run_test "T014-INT-1: Agent documentation shows complete workflow from input to output"
if grep -qiE "Step [1-9]|workflow|pipeline" "$AGENT_FILE" && grep -q "=== Task.*done ===" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show complete workflow with steps and output format"
    FAILED=$((FAILED + 1))
fi

run_test "T014-INT-2: Agent documentation includes usage examples"
if grep -qiE "Usage.*Example|## Usage|Example:" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must include usage examples section"
    FAILED=$((FAILED + 1))
fi

run_test "T014-INT-3: Agent documentation shows single task orchestration"
if grep -qiE "Single task:|single.*task.*example" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show single task orchestration example"
    FAILED=$((FAILED + 1))
fi

run_test "T014-INT-4: Agent documentation shows multi-task orchestration"
if grep -qiE "Multiple tasks:|multi.*task.*example" "$AGENT_FILE" || (grep -q "Task 1:" "$AGENT_FILE" && grep -q "Task 2:" "$AGENT_FILE"); then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must show multi-task orchestration example"
    FAILED=$((FAILED + 1))
fi

run_test "T014-INT-5: Agent documentation includes constitution compliance checklist"
if grep -qiE "Constitution|Principle|✅.*Principle" "$AGENT_FILE"; then
    echo "  ✓ PASS: $TEST_NAME"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: $TEST_NAME"
    echo "    Agent file must include constitution compliance section"
    FAILED=$((FAILED + 1))
fi

echo ""

# Phase 5 tests will be added here (T013, T014)

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
