#!/bin/bash
# tests/unit/test_error_memory.sh
#
# Test suite for Error-Memory Persistence writer
# Task T0445: Validate append format, idempotence, and deduplication
#
# Validates that src/error_memory/writer.sh correctly appends entries and
# deduplicates same-category+message errors within a 1-hour window.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  if (export SPECFARM_ROOT="$test_root"; MEM_FILE="$test_root/.specfarm/error-memory.md"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# ---- Test: writer exits 0 and produces output ----
t0445_exits_zero() {
  local out
  out=$(bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "test-cat" --message "test msg" --file "$MEM_FILE" 2>&1)
  [[ $? -eq 0 ]] && [[ -n "$out" ]]
}

# ---- Test: entry is appended to the file ----
t0445_entry_appended() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "network" --message "connection refused" --file "$MEM_FILE" >/dev/null 2>&1
  [[ -f "$MEM_FILE" ]] && grep -q "ERROR: network — connection refused" "$MEM_FILE"
}

# ---- Test: entry follows the schema [timestamp] ERROR: <category> — <message> ----
t0445_entry_format() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "auth" --message "token expired" --file "$MEM_FILE" >/dev/null 2>&1
  # Validate schema: [ISO-timestamp] ERROR: <cat> — <msg>
  grep -qE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] ERROR: auth — token expired$' "$MEM_FILE"
}

# ---- Test: multiple distinct entries are all appended ----
t0445_multiple_entries() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "drift" --message "rule-1 violated" --file "$MEM_FILE" >/dev/null 2>&1
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "drift" --message "rule-2 violated" --file "$MEM_FILE" >/dev/null 2>&1
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "shell" --message "command not found" --file "$MEM_FILE" >/dev/null 2>&1
  local count
  count=$(wc -l < "$MEM_FILE" | tr -d ' ')
  [[ "$count" -eq 3 ]]
}

# ---- Test: idempotent — same error not added twice within 1 hour ----
t0445_idempotent_no_duplicate() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "build" --message "compile failed" --file "$MEM_FILE" >/dev/null 2>&1
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "build" --message "compile failed" --file "$MEM_FILE" >/dev/null 2>&1
  local count
  count=$(wc -l < "$MEM_FILE" | tr -d ' ')
  [[ "$count" -eq 1 ]]
}

# ---- Test: second call exits 0 even when deduplicated (SKIP is not an error) ----
t0445_dedup_exits_zero() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "lint" --message "missing shebang" --file "$MEM_FILE" >/dev/null 2>&1
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "lint" --message "missing shebang" --file "$MEM_FILE" >/dev/null 2>&1
  [[ $? -eq 0 ]]
}

# ---- Test: different messages under same category both written ----
t0445_same_cat_diff_msg() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "ci" --message "step A failed" --file "$MEM_FILE" >/dev/null 2>&1
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "ci" --message "step B failed" --file "$MEM_FILE" >/dev/null 2>&1
  local count
  count=$(wc -l < "$MEM_FILE" | tr -d ' ')
  [[ "$count" -eq 2 ]]
}

# ---- Test: missing --category or --message exits 1 ----
t0445_missing_args_exit_1() {
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "only-cat" --file "$MEM_FILE" >/dev/null 2>&1
  [[ $? -ne 0 ]]
}

# ---- Test: directory is created when it does not exist ----
t0445_creates_directory() {
  local new_dir="$MEM_FILE/../sub/.specfarm"
  bash "$REPO_ROOT/src/error_memory/writer.sh" \
    --category "x" --message "y" --file "${new_dir}/error-memory.md" >/dev/null 2>&1
  [[ -d "$new_dir" ]]
}

echo "=== Unit Tests: Error-Memory Persistence (T0445) ==="
_run_test "T0445: writer exits 0 and produces output"          t0445_exits_zero
_run_test "T0445: entry is appended to file"                   t0445_entry_appended
_run_test "T0445: entry follows [timestamp] ERROR: cat — msg"  t0445_entry_format
_run_test "T0445: multiple distinct entries all appended"       t0445_multiple_entries
_run_test "T0445: idempotent — no duplicate within 1 hour"     t0445_idempotent_no_duplicate
_run_test "T0445: deduplicated call still exits 0"             t0445_dedup_exits_zero
_run_test "T0445: same category, different messages both saved" t0445_same_cat_diff_msg
_run_test "T0445: missing args exits non-zero"                 t0445_missing_args_exit_1
_run_test "T0445: creates .specfarm directory if missing"      t0445_creates_directory

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
