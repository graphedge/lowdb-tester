#!/bin/bash
# Inference Engine for SpecFarm

# Scores a line based on keyword certainty
score_certainty() {
    local text="$1"
    local score=0.5 # Default score
    
    # Check fuzzy terms first to catch "should consider" etc.
    if echo "$text" | grep -qiE "defer|consider|eventually|maybe|perhaps"; then
        score=0.6
    # Check fuzzy 'should' (lowercase or mixed, not all caps)
    elif echo "$text" | grep -q "should" && ! echo "$text" | grep -q "SHOULD"; then
        score=0.6
    # High certainty
    elif echo "$text" | grep -qiE "enforce from Phase|required starting in|MUST|MANDATORY"; then
        score=1.0
    elif echo "$text" | grep -qiE "Phase [1-9]|Starting in [0-9]"; then
        score=0.9
    # Moderate certainty
    elif echo "$text" | grep -qiE "SHOULD|IMPORTANT"; then
        score=0.8
    fi
    
    echo "$score"
}

# Detects conflicts between tasks
# For now, very simple: if both 'MUST' and 'defer' are present in the same block
detect_conflict() {
    local text="$1"
    if echo "$text" | grep -qi "MUST" && echo "$text" | grep -qi "defer"; then
        return 0 # Conflict found
    fi
    return 1 # No conflict
}
