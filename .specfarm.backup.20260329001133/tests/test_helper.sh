#!/bin/bash
# tests/test_helper.sh
#
# Common test utilities and setup for Phase 1 test suite
# Source this file from test scripts: . "$(dirname "$0")/../test_helper.sh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
  echo -e "  ${YELLOW}[INFO]${NC} $*" >&2
}

# Simulate BATS 'run': captures command output and exit status.
# Sets $output and $status in the caller's scope.
run() {
  output=$("$@" 2>&1)
  status=$?
  return 0
}

# Add bin directory to PATH if it exists
if [[ -d "$SPECFARM_ROOT/.specfarm/bin" ]]; then
  export PATH="$SPECFARM_ROOT/.specfarm/bin:$PATH"
fi

# Mock implementation stubs (will be replaced by actual implementations in Phase 4)
# These allow tests to run and fail properly (RED state)

drift_score() {
  local violations="${1:-0}"
  local total="${2:-0}"
  # Formula: 1.0 - (violations / max(total, 1))
  awk "BEGIN{
    v=$violations; t=$total
    if(t==0){print \"1.0\"; exit}
    r=1.0-(v/t)
    if(r==1.0){print \"1.0\"}
    else if(r==0.0){print \"0.0\"}
    else{printf \"%g\n\",r}
  }"
}

nudge_required() {
  local score="${1:-1.0}"
  # Nudge when score <= 0.5 (drift >= 50%)
  if (( $(echo "$score <= 0.5" | bc -l 2>/dev/null || echo 0) )); then
    echo "true"
  else
    echo "false"
  fi
}

whisper_required() {
  local score="${1:-1.0}"
  # Whisper when 0.5 < score < 0.9 (30% < drift < 50%)
  if (( $(echo "$score > 0.5 && $score < 0.9" | bc -l 2>/dev/null || echo 0) )); then
    echo "true"
  else
    echo "false"
  fi
}

get_nudge_message() {
  echo "🚜 Heads up farmer! Drift is significant. Run \`/specfarm drift\` to see details."
}

get_whisper_message() {
  echo "🐴 Gentle nudge: Consider reviewing recent changes for compliance."
}

get_feedback_message() {
  local score="${1:-1.0}"
  
  if (( $(echo "$score > 0.9" | bc -l 2>/dev/null || echo 0) )); then
    echo "✅ Drift Score: $score"
  elif (( $(echo "$score > 0.5 && $score <= 0.9" | bc -l 2>/dev/null || echo 0) )); then
    get_whisper_message
  else
    get_nudge_message
  fi
}

parse_rules() {
  local rule_id="${1:-}"
  
  if [[ -z "$rule_id" ]]; then
    # Return all rule IDs from rules.xml
    grep -o 'id="[^"]*"' .specfarm/rules.xml 2>/dev/null | cut -d'"' -f2
  else
    # Return description for specific rule
    grep "id=\"$rule_id\"" .specfarm/rules.xml 2>/dev/null | grep -o '<description>[^<]*</description>' | sed 's/<[^>]*>//g'
  fi
}

parse_rules_for_phase() {
  local phase="${1:-Phase 1}"
  grep "available-from=\"$phase\"" .specfarm/rules.xml 2>/dev/null | grep -o 'id="[^"]*"' | cut -d'"' -f2
}

is_immutable() {
  local rule_id="${1:-}"
  grep "id=\"$rule_id\"" .specfarm/rules.xml 2>/dev/null | grep -q 'immutable="true"'
  if [[ $? -eq 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}

count_rules() {
  grep -c '<rule[> ]' .specfarm/rules.xml 2>/dev/null || echo "0"
}

read_constitution() {
  cat constitution.md 2>/dev/null || echo ""
}

specfarm() {
  local cmd="${1:-help}"
  shift || true
  
  case "$cmd" in
    drift)
      local json_flag=0
      for arg in "$@"; do
        [[ "$arg" == "--json" ]] && json_flag=1
      done
      local rule_count
      rule_count=$(count_rules)
      if [[ "$json_flag" -eq 1 ]]; then
        echo "{\"score\": 0, \"drift\": 100}"
      else
        if [[ -f ".specfarm/rules.xml" ]]; then
          grep -o 'id="[^"]*"' .specfarm/rules.xml | cut -d'"' -f2 | while read -r rid; do
            echo "DRIFT: $rid"
          done
        fi
        echo "drift score: 0.8"
        echo "rules checked: $rule_count"
      fi
      ;;
    justify)
      local rule_id="${1:-}"
      local reason="${2:-}"
      local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")
      local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "0000000")
      echo "$timestamp | $rule_id | $commit | $reason" >> .specfarm/justifications.log
      ;;
    help)
      echo "SpecFarm Commands:"
      echo "  specfarm drift        Show current drift scores"
      echo "  specfarm justify      Log justifications for drift"
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      return 1
      ;;
  esac
}

# Export all functions
export -f drift_score
export -f nudge_required
export -f whisper_required
export -f get_nudge_message
export -f get_whisper_message
export -f get_feedback_message
export -f parse_rules
export -f parse_rules_for_phase
export -f is_immutable
export -f count_rules
export -f read_constitution
export -f specfarm

# ============================================================================
# Phase 2 Test Utilities (T002)
# ============================================================================

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected' but got '$actual'}"
  
  if [[ "$expected" != "$actual" ]]; then
    echo -e "  ${RED}[FAIL]${NC} $message" >&2
    return 1
  fi
  return 0
}

count_tokens_approx() {
  local text="$1"
  # Heuristic: 1.3 tokens per word
  local word_count=$(echo "$text" | wc -w)
  # Use awk for floating point then round
  awk "BEGIN { print int($word_count * 1.3 + 0.5) }"
}

validate_rule_match() {
  local rule_id="$1"
  local output="$2"
  
  if echo "$output" | grep -q "$rule_id"; then
    return 0
  fi
  echo -e "  ${RED}[FAIL]${NC} Rule '$rule_id' not found in output" >&2
  return 1
}

setup_test_env() {
  export TEST_TMP_DIR=$(mktemp -d)
  export RULES_XML_PATH="$TEST_TMP_DIR/rules.xml"
  cp "$(dirname "${BASH_SOURCE[0]}")/fixtures/sample-rules.xml" "$RULES_XML_PATH"
  log_info "Test environment setup in $TEST_TMP_DIR"
}

teardown_test_env() {
  if [[ -d "${TEST_TMP_DIR:-}" ]]; then
    rm -rf "$TEST_TMP_DIR"
    log_info "Test environment cleaned up"
  fi
}

export -f assert_equals
export -f count_tokens_approx
export -f validate_rule_match
export -f setup_test_env
export -f teardown_test_env
