#!/bin/bash
# tests/unit/test_confidence_scoring.sh
# T006: Unit tests for calculate_confidence() scoring algorithm
# All tests use COMMIT_LOG_OVERRIDE and RULES_XML_PATH for zero-dependency isolation.

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running confidence scoring tests..."

# Load logging helpers and calculate_confidence from agent (avoid running main)
TMP_FUNC_FILE=$(mktemp)
{
    sed -n '/^log_section() {/,/^}/p' "$AGENT"
    sed -n '/^log_info() {/,/^}/p' "$AGENT"
    sed -n '/^log_done() {/,/^}/p' "$AGENT"
    sed -n '/^log_warn() {/,/^}/p' "$AGENT"
    sed -n '/^log_error() {/,/^}/p' "$AGENT"
    sed -n '/^calculate_confidence() {/,/^}/p' "$AGENT"
} > "$TMP_FUNC_FILE"
export RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml"
# shellcheck disable=SC1090
. "$TMP_FUNC_FILE"
rm "$TMP_FUNC_FILE"

# ── Test 1: High confidence (≥90%) for rules with 5+ commits by different authors ─────
echo "Test 1: High confidence for 5+ commits by different authors"
COMMIT_LOG_OVERRIDE="author1 abc1 fix: r_bash_001 issue
author2 abc2 test: r_bash_001 coverage
author3 abc3 feat: r_bash_001 enhancement
author4 abc4 docs: r_bash_001 note
author5 abc5 refactor: r_bash_001 cleanup"
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "")
if [[ "$score" -ge 90 ]]; then
  echo "✓ PASS: Score=$score (≥90 for 5+ commits by 5 authors)"
else
  echo "✗ FAIL: Expected ≥90 for 5 authors, got $score"
  exit 1
fi

# ── Test 2: Medium confidence (70-89%) for rules with 2-4 commits ─────────────────────
echo "Test 2: Medium confidence for 2-4 commits"
COMMIT_LOG_OVERRIDE="author1 abc1 fix: r_path_001 issue
author2 abc2 test: r_path_001 coverage
author3 abc3 feat: r_path_001 enhancement"
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_path_001" "")
if [[ "$score" -ge 70 && "$score" -le 89 ]]; then
  echo "✓ PASS: Score=$score (70-89 for 3 commits, 3 authors, with constitution ref)"
else
  echo "✗ FAIL: Expected 70-89 for 3 authors+commits, got $score"
  exit 1
fi

# ── Test 3: Low confidence (<70%) for rules with single occurrence ─────────────────────
echo "Test 3: Low confidence for single commit"
COMMIT_LOG_OVERRIDE="author1 abc1 fix: r_xml_001 issue"
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_xml_001" "")
if [[ "$score" -lt 70 ]]; then
  echo "✓ PASS: Score=$score (<70 for single commit)"
else
  echo "✗ FAIL: Expected <70 for single commit, got $score"
  exit 1
fi

# ── Test 4: Bonus scoring for test coverage link (+20) ────────────────────────────────
echo "Test 4: Bonus for test_link in metadata"
# r_bash_001 has test_link; r_git_001 does not — compare with same commit history
COMMIT_LOG_OVERRIDE="author1 abc1 fix: rule issue"
score_with=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "")
score_without=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_git_001" "")
if [[ $((score_with - score_without)) -eq 20 ]]; then
  echo "✓ PASS: test_link adds exactly 20 points (with=$score_with, without=$score_without)"
else
  echo "✗ FAIL: Expected 20-point bonus for test_link (diff=$((score_with - score_without)))"
  exit 1
fi

# ── Test 5: Bonus scoring for constitution reference (+20) ────────────────────────────
echo "Test 5: Bonus for constitution reference in metadata"
# r_bash_001 has constitution note; compare with a rule that has no constitution ref
# All fixture rules have constitution refs, so test the scoring component in isolation.
# This test verifies the component is counted: score with same commits but rule with
# constitution ref should be ≥20 more than 0-base (no commits, no test_link, no const).
COMMIT_LOG_OVERRIDE=""
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "")
# r_bash_001: no commits (+0), has test_link (+20), has constitution ref (+20) = 40
if [[ "$score" -eq 40 ]]; then
  echo "✓ PASS: Score=$score (constitution ref +20 + test_link +20 with no commits)"
else
  echo "✗ FAIL: Expected 40 (test_link+const with no commits), got $score"
  exit 1
fi

# ── Test 6: Keyword match scoring (+15 per match) ────────────────────────────────────
echo "Test 6: Keyword match scoring (+15 per match)"
COMMIT_LOG_OVERRIDE=""
# r_bash_001 name "Bash Arithmetic Guard" — keyword "Bash" should match
score_no_kw=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "")
score_kw=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "Bash")
diff=$((score_kw - score_no_kw))
if [[ "$diff" -eq 15 ]]; then
  echo "✓ PASS: Keyword 'Bash' adds exactly 15 points (no_kw=$score_no_kw, kw=$score_kw)"
else
  echo "✗ FAIL: Expected +15 for 1 keyword match, got diff=$diff (no_kw=$score_no_kw, kw=$score_kw)"
  exit 1
fi

# ── Test 7: Score capped at 100 ──────────────────────────────────────────────────────
echo "Test 7: Score capped at 100"
# 6 commits by 6 different authors: +30 (commits) +10 (2+ authors) +20 (test_link) +20 (const) +15*3 (keywords) = 125 → capped at 100
COMMIT_LOG_OVERRIDE="a1 h1 note
a2 h2 note
a3 h3 note
a4 h4 note
a5 h5 note
a6 h6 note"
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_bash_001" "Bash Arithmetic Guard")
if [[ "$score" -eq 100 ]]; then
  echo "✓ PASS: Score capped at 100 (calculated would exceed 100)"
else
  echo "✗ FAIL: Expected score capped at 100, got $score"
  exit 1
fi

# ── Test 8: Score floored at 0 ───────────────────────────────────────────────────────
echo "Test 8: Score floored at 0 (no negative scores)"
# Artificial rule that doesn't exist in rules.xml → no bonuses, all checks return 0
COMMIT_LOG_OVERRIDE=""
score=$(COMMIT_LOG_OVERRIDE="$COMMIT_LOG_OVERRIDE" calculate_confidence "r_nonexistent_999" "")
if [[ "$score" -eq 0 ]]; then
  echo "✓ PASS: Score is 0 for nonexistent rule (no negative)"
else
  echo "✗ FAIL: Expected 0 for nonexistent rule, got $score"
  exit 1
fi

echo "All confidence scoring tests passed"
