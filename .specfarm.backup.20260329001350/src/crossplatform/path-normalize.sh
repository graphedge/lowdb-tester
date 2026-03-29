#!/bin/bash
# src/crossplatform/path-normalize.sh — Cross-platform path conversion
# Phase 3b T006: Transparently convert paths between Unix (/) and Windows (\)
# Usage: source this file, then call normalize_path, to_unix_path, to_windows_path

# ------------------------------------------------------------------
# Normalize to Unix-style forward slashes
# Accepts: C:\Users\foo\bar  or  /c/Users/foo/bar  or  already Unix
# Returns: /c/Users/foo/bar  (POSIX-compatible, Git Bash / WSL style)
# ------------------------------------------------------------------
to_unix_path() {
    local path="$1"
    [[ -z "$path" ]] && return 0

    # Replace backslashes with forward slashes
    path="${path//\\//}"

    # Convert Windows drive letter  C:/...  →  /c/...
    if [[ "$path" =~ ^([A-Za-z]):/(.*) ]]; then
        local drive="${BASH_REMATCH[1],,}"  # lowercase
        local rest="${BASH_REMATCH[2]}"
        path="/${drive}/${rest}"
    fi

    echo "$path"
}

# ------------------------------------------------------------------
# Normalize to Windows-style backslashes
# Accepts: /c/Users/foo/bar  or  C:/Users/foo  or already Windows
# Returns: C:\Users\foo\bar
# ------------------------------------------------------------------
to_windows_path() {
    local path="$1"
    [[ -z "$path" ]] && return 0

    # Convert Git Bash / WSL  /c/Users  →  C:/Users  before slashing
    if [[ "$path" =~ ^/([a-zA-Z])/(.*) ]]; then
        local drive="${BASH_REMATCH[1]^^}"  # uppercase
        local rest="${BASH_REMATCH[2]}"
        path="${drive}:/${rest}"
    fi

    # Replace forward slashes with backslashes
    path=$(echo "$path" | sed 's|/|\\|g')
    echo "$path"
}

# ------------------------------------------------------------------
# Auto-detect format and normalize to current platform's preferred style
# On Linux/macOS → Unix; on Windows (Cygwin/MSYS/WSL) → still Unix
# (Windows paths are only needed when passing to native Win32 programs)
# ------------------------------------------------------------------
normalize_path() {
    local path="$1"
    [[ -z "$path" ]] && return 0
    # Always normalize to Unix format for SpecFarm internal use
    to_unix_path "$path"
}

# ------------------------------------------------------------------
# Normalize all path fields in a JSON string (for shell-errors.log)
# Replaces Windows paths in "cwd" and "command" fields
# ------------------------------------------------------------------
normalize_json_paths() {
    local json="$1"
    [[ -z "$json" ]] && return 0

    # Convert C:\ patterns to /c/ in the JSON string (for comparison)
    echo "$json" | sed -E \
        -e 's|([A-Za-z]):\\\\|/\L\1/|g' \
        -e 's|([A-Za-z]):\\|/\L\1/|g' \
        -e 's|\\\\|/|g'
}

# ------------------------------------------------------------------
# Self-test
# ------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Path Normalize Self-Test ==="
    tests_passed=0
    tests_failed=0

    run_test() {
        local desc="$1" input="$2" expected="$3" fn="$4"
        local actual
        actual=$("$fn" "$input")
        if [[ "$actual" == "$expected" ]]; then
            echo "PASS: $desc"
            ((tests_passed++))
        else
            echo "FAIL: $desc — expected '$expected', got '$actual'"
            ((tests_failed++))
        fi
    }

    run_test "Windows backslash → Unix"    'C:\Users\foo\bar'   '/c/Users/foo/bar'   to_unix_path
    run_test "Already Unix path"           '/home/user/project' '/home/user/project' to_unix_path
    run_test "Git Bash /c/ path"           '/c/Users/foo'       '/c/Users/foo'       to_unix_path
    run_test "Unix → Windows"              '/c/Users/foo/bar'   'C:\Users\foo\bar'   to_windows_path
    run_test "Mixed slashes → Unix"        'C:/Users/foo'       '/c/Users/foo'       to_unix_path

    echo "---"
    echo "Tests passed: $tests_passed  Failed: $tests_failed"
    [[ "$tests_failed" -eq 0 ]]
fi
