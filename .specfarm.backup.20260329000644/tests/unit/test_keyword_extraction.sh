#!/bin/bash
# tests/unit/test_keyword_extraction.sh

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running keyword extraction tests..."

# Extract the function to avoid sourcing the whole script
TMP_FUNC_FILE=$(mktemp)
sed -n '/^extract_task_keywords() {/,/^}/p' "$AGENT" > "$TMP_FUNC_FILE"
. "$TMP_FUNC_FILE"
rm "$TMP_FUNC_FILE"

# Test 1: Extract file paths
echo "Test 1: Extract file paths"
res=$(extract_task_keywords "Fix bash arithmetic guard in test_drift.sh")
if echo "$res" | grep -q "test_drift.sh"; then
  echo "✓ PASS: Found test_drift.sh"
else
  echo "✗ FAIL: test_drift.sh not found in '$res'"
  exit 1
fi

# Test 2: Extract test patterns
echo "Test 2: Extract test patterns"
res=$(extract_task_keywords "Implement test_platform_detection")
if echo "$res" | grep -q "test_platform_detection"; then
  echo "✓ PASS: Found test_platform_detection"
else
  echo "✗ FAIL: test_platform_detection not found in '$res'"
  exit 1
fi

# Test 3: Extract directories
echo "Test 3: Extract directories"
res=$(extract_task_keywords "Refactor tests/unit and src/logic")
if echo "$res" | grep -q "tests/unit" && echo "$res" | grep -q "src/logic"; then
  echo "✓ PASS: Found directories"
else
  echo "✗ FAIL: Directories not found in '$res'"
  exit 1
fi

# Test 4: Extract action verbs
echo "Test 4: Extract action verbs"
res=$(extract_task_keywords "fix and implement things")
if echo "$res" | grep -q "fix" && echo "$res" | grep -q "implement"; then
  echo "✓ PASS: Found action verbs"
else
  echo "✗ FAIL: Action verbs not found in '$res'"
  exit 1
fi

echo "All tests passed"
