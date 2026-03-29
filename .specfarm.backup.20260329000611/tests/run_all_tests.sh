#!/bin/bash
# tests/run_all_tests.sh
#
# Unified test runner for all SpecFarm tests
# Zero external dependencies — runs with plain /bin/bash
#
# Usage:
#   /bin/bash tests/run_all_tests.sh          # run all tests
#   /bin/bash tests/run_all_tests.sh unit     # run only unit tests
#   /bin/bash tests/run_all_tests.sh integration
#   /bin/bash tests/run_all_tests.sh e2e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="${1:-all}"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
FAILED_FILES=()

run_test_file() {
  local file="$1"
  local label
  label="$(basename "$file")"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $label"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local output
  output=$(bash "$file" 2>&1)
  local exit_code=$?

  echo "$output"

  local passes fails
  passes=$(echo "$output" | grep -c '^PASS:' || true)
  fails=$(echo "$output" | grep -c '^FAIL:' || true)

  TOTAL_PASS=$((TOTAL_PASS + passes))
  TOTAL_FAIL=$((TOTAL_FAIL + fails))

  if [ "$exit_code" -ne 0 ]; then
    FAILED_FILES+=("$label")
  fi
}

collect_files() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name "test_*.sh" -type f | sort
}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           SpecFarm Test Suite — Zero Dependencies        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  Shell: $(bash --version | head -1)"
echo "  Date:  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if [[ "$FILTER" == "all" || "$FILTER" == "unit" ]]; then
  echo ""
  echo "[ Unit Tests ]"
  while IFS= read -r f; do
    run_test_file "$f"
  done < <(collect_files "$TESTS_DIR/unit")
fi

if [[ "$FILTER" == "all" || "$FILTER" == "integration" ]]; then
  echo ""
  echo "[ Integration Tests ]"
  while IFS= read -r f; do
    run_test_file "$f"
  done < <(collect_files "$TESTS_DIR/integration")
fi

if [[ "$FILTER" == "all" || "$FILTER" == "e2e" ]]; then
  echo ""
  echo "[ E2E Tests ]"
  while IFS= read -r f; do
    run_test_file "$f"
  done < <(collect_files "$TESTS_DIR/e2e")
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    SUMMARY                               ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  %-20s  %-5d                              ║\n" "Tests passed:" "$TOTAL_PASS"
printf "║  %-20s  %-5d                              ║\n" "Tests failed:" "$TOTAL_FAIL"
echo "╚══════════════════════════════════════════════════════════╝"

if [ "${#FAILED_FILES[@]}" -gt 0 ]; then
  echo ""
  echo "Failed files:"
  for f in "${FAILED_FILES[@]}"; do
    echo "  ✗ $f"
  done
fi

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo ""
  echo "✓ All tests passed."
  exit 0
else
  echo ""
  echo "✗ $TOTAL_FAIL test(s) failed."
  exit 1
fi
