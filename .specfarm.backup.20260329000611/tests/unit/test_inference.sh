#!/bin/bash
# Unit test for certainty scoring in SpecFarm

set -euo pipefail

source .specfarm/src/export/inference_engine.sh

test_score() {
    local text="$1"
    local expected="$2"
    local actual=$(score_certainty "$text")
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: '$text' -> $actual"
    else
        echo "FAIL: '$text' -> expected $expected, got $actual"
        exit 1
    fi
}

test_score "enforce from Phase 2" "1.0"
test_score "required starting in 2.0" "1.0"
test_score "Phase 2" "0.9"
test_score "SHOULD use better names" "0.8"
test_score "we should consider deferring this" "0.6"
test_score "completely unrelated task" "0.5"

test_conflict() {
    local text="$1"
    local expected="$2"
    if detect_conflict "$text"; then
        actual="true"
    else
        actual="false"
    fi
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: Conflict '$text' -> $actual"
    else
        echo "FAIL: Conflict '$text' -> expected $expected, got $actual"
        exit 1
    fi
}

test_conflict "We MUST do this but we should defer it." "true"
test_conflict "We MUST do this now." "false"
test_conflict "We should defer this later." "false"

echo "All certainty scoring and conflict detection tests PASSED"

