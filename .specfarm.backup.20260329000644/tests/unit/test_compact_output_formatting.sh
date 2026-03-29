#!/bin/bash
# tests/unit/test_compact_output_formatting.sh
# T011: Unit tests for format_task_context_output()

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running compact output formatting tests..."

TMP_FUNC_FILE=$(mktemp)
{
    sed -n '/^log_section() {/,/^}/p' "$AGENT"
    sed -n '/^log_info() {/,/^}/p' "$AGENT"
    sed -n '/^log_done() {/,/^}/p' "$AGENT"
    sed -n '/^log_warn() {/,/^}/p' "$AGENT"
    sed -n '/^log_error() {/,/^}/p' "$AGENT"
    sed -n '/^format_task_context_output() {/,/^}/p' "$AGENT"
} > "$TMP_FUNC_FILE"
# shellcheck disable=SC1090
. "$TMP_FUNC_FILE"
rm "$TMP_FUNC_FILE"
export RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml"

# ── Test 1: Default mode output contains required sections ───────────────────
echo "Test 1: Default output structure"
output=$(format_task_context_output \
    "Fix bash arithmetic guard" \
    "r_bash_001:90 r_path_001:75" \
    "abc123: fix arithmetic issue" \
    "default" 2>&1)
if echo "$output" | grep -q "## Context for:" && \
   echo "$output" | grep -q "Applicable Rules" && \
   echo "$output" | grep -q "Recent Evidence"; then
  echo "✓ PASS: Default output contains required sections"
else
  echo "✗ FAIL: Missing required sections in default output"
  echo "$output"
  exit 1
fi

# ── Test 2: Default output includes constitution reference section ────────────
echo "Test 2: Constitution reference in default mode"
output=$(format_task_context_output \
    "Fix bash arithmetic guard" \
    "r_bash_001:90" \
    "abc123: fix issue" \
    "default" 2>&1)
if echo "$output" | grep -q "Constitution"; then
  echo "✓ PASS: Default output includes constitution section"
else
  echo "✗ FAIL: Missing constitution section in default mode"
  echo "$output"
  exit 1
fi

# ── Test 3: Tiny mode omits constitution reference section ───────────────────
echo "Test 3: Tiny mode omits constitution section"
output=$(format_task_context_output \
    "Fix bash arithmetic guard" \
    "r_bash_001:90" \
    "abc123: fix issue" \
    "tiny" 2>&1)
if ! echo "$output" | grep -q "Constitution Reference"; then
  echo "✓ PASS: Tiny mode omits constitution section"
else
  echo "✗ FAIL: Tiny mode should NOT include constitution section"
  echo "$output"
  exit 1
fi

# ── Test 4: Tiny mode output is within ~100 token budget ────────────────────
echo "Test 4: Tiny mode token budget (~100 tokens)"
output=$(format_task_context_output \
    "Fix bash arithmetic guard" \
    "r_bash_001:90 r_path_001:75" \
    "abc123: fix issue" \
    "tiny" 2>&1)
token_count=$(count_tokens_approx "$output")
if [[ "$token_count" -le 120 ]]; then
  echo "✓ PASS: Tiny output is within budget ($token_count tokens)"
else
  echo "✗ FAIL: Tiny output exceeds 120-token budget ($token_count tokens)"
  echo "$output"
  exit 1
fi

echo "All compact output formatting tests passed"
