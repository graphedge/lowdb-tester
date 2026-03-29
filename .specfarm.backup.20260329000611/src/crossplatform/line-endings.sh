#!/bin/bash
# src/crossplatform/line-endings.sh — CRLF ↔ LF conversion for .specfarm/ files
# Phase 3b T007: Ensure rules.xml, justifications.log, shell-errors.log use LF on all platforms
# Usage: source this file, then call normalize_line_endings, fix_specfarm_files

# ------------------------------------------------------------------
# Convert CRLF → LF in a file (in-place)
# Safe on both Linux and macOS (no gnu-sed dependency)
# ------------------------------------------------------------------
crlf_to_lf_file() {
    local file="$1"
    [[ -f "$file" ]] || { echo "Error: file not found: $file" >&2; return 1; }

    # Use tr (POSIX, available everywhere)
    local tmp
    tmp=$(mktemp)
    tr -d '\r' < "$file" > "$tmp" && mv "$tmp" "$file"
}

# ------------------------------------------------------------------
# Convert CRLF → LF in a string (stdin → stdout)
# ------------------------------------------------------------------
crlf_to_lf_string() {
    tr -d '\r'
}

# ------------------------------------------------------------------
# Convert LF → CRLF in a file (in-place) — for writing to Windows targets
# ------------------------------------------------------------------
lf_to_crlf_file() {
    local file="$1"
    [[ -f "$file" ]] || { echo "Error: file not found: $file" >&2; return 1; }

    local tmp
    tmp=$(mktemp)
    # sed portable: insert \r before every \n
    sed 's/$/\r/' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ------------------------------------------------------------------
# Detect line endings in a file
# Returns: "lf", "crlf", "mixed", or "empty"
# ------------------------------------------------------------------
detect_line_endings() {
    local file="$1"
    [[ -f "$file" ]] || { echo "empty"; return 0; }
    [[ ! -s "$file" ]] && { echo "empty"; return 0; }

    local cr_count lf_count
    cr_count=$(tr -cd '\r' < "$file" | wc -c)
    lf_count=$(tr -cd '\n' < "$file" | wc -c)

    if [[ "$cr_count" -eq 0 && "$lf_count" -gt 0 ]]; then
        echo "lf"
    elif [[ "$cr_count" -gt 0 && "$cr_count" -eq "$lf_count" ]]; then
        echo "crlf"
    elif [[ "$cr_count" -gt 0 ]]; then
        echo "mixed"
    else
        echo "empty"
    fi
}

# ------------------------------------------------------------------
# Normalize all .specfarm/ tracked files to LF
# Targets: rules.xml, justifications.log, shell-errors.log, config
# ------------------------------------------------------------------
fix_specfarm_files() {
    local specfarm_dir="${1:-.specfarm}"

    local normalized=0
    local skipped=0

    for target_file in \
        "$specfarm_dir/rules.xml" \
        "$specfarm_dir/justifications.log" \
        "$specfarm_dir/shell-errors.log" \
        "$specfarm_dir/config"; do

        [[ -f "$target_file" ]] || { ((skipped++)); continue; }

        local endings
        endings=$(detect_line_endings "$target_file")

        if [[ "$endings" == "crlf" || "$endings" == "mixed" ]]; then
            crlf_to_lf_file "$target_file"
            echo "Normalized: $target_file ($endings → lf)"
            ((normalized++))
        fi
    done

    echo "Line-ending normalization: $normalized files fixed, $skipped not found"
}

# ------------------------------------------------------------------
# Self-test
# ------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Line Endings Self-Test ==="
    passed=0
    failed=0

    # Test 1: CRLF detection
    tmp=$(mktemp)
    printf "line1\r\nline2\r\n" > "$tmp"
    result=$(detect_line_endings "$tmp")
    if [[ "$result" == "crlf" ]]; then echo "PASS: CRLF detection"; ((passed++)); else echo "FAIL: CRLF detection — got $result"; ((failed++)); fi

    # Test 2: LF detection
    printf "line1\nline2\n" > "$tmp"
    result=$(detect_line_endings "$tmp")
    if [[ "$result" == "lf" ]]; then echo "PASS: LF detection"; ((passed++)); else echo "FAIL: LF detection — got $result"; ((failed++)); fi

    # Test 3: CRLF → LF conversion
    printf "line1\r\nline2\r\n" > "$tmp"
    crlf_to_lf_file "$tmp"
    result=$(detect_line_endings "$tmp")
    if [[ "$result" == "lf" ]]; then echo "PASS: CRLF→LF conversion"; ((passed++)); else echo "FAIL: CRLF→LF conversion — got $result"; ((failed++)); fi

    # Test 4: Empty file
    > "$tmp"
    result=$(detect_line_endings "$tmp")
    if [[ "$result" == "empty" ]]; then echo "PASS: Empty file detection"; ((passed++)); else echo "FAIL: Empty file — got $result"; ((failed++)); fi

    rm -f "$tmp"
    echo "---"
    echo "Tests passed: $passed  Failed: $failed"
    [[ "$failed" -eq 0 ]]
fi
