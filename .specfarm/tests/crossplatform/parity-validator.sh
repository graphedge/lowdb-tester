#!/bin/bash
# tests/crossplatform/parity-validator.sh — Output normalization pipeline for bash/PowerShell parity
# Phase 3b T011a: Normalize outputs before diff comparison
#
# Usage (stdin pipeline):
#   bash parity-validator.sh [--mode <full|paths|ansi|timestamps|whitespace>]
#   echo "$output" | bash tests/crossplatform/parity-validator.sh
#
# Or normalize a file:
#   bash tests/crossplatform/parity-validator.sh --file /path/to/output.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="full"
INPUT_FILE=""

usage() {
    cat <<'EOF'
parity-validator.sh — Normalize outputs for bash/PowerShell parity comparison

Reads from stdin (or --file) and writes normalized output to stdout.

Options:
  --mode full          Apply all normalizations (default)
  --mode paths         Normalize file paths only
  --mode ansi          Strip ANSI color codes only
  --mode timestamps    Replace timestamps with TIMESTAMP placeholder only
  --mode whitespace    Strip trailing whitespace + normalize line endings only
  --file PATH          Read from file instead of stdin
  --help               Show this help

Normalization pipeline (applied in order for "full" mode):
  1. CRLF → LF (line endings)
  2. Strip ANSI/VT100 escape sequences
  3. Windows paths → Unix paths (C:\foo → /c/foo)
  4. Timestamps → TIMESTAMP placeholder
  5. Trailing whitespace stripped
  6. Env variable paths → placeholder (opt, partial)

Examples:
  echo "$bash_output"  | bash parity-validator.sh > normalized_bash.txt
  echo "$pwsh_output"  | bash parity-validator.sh > normalized_pwsh.txt
  diff normalized_bash.txt normalized_pwsh.txt && echo "PARITY"
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --file) INPUT_FILE="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# ------------------------------------------------------------------
# Step 1: Normalize line endings (CRLF → LF)
# ------------------------------------------------------------------
normalize_line_endings() {
    tr -d '\r'
}

# ------------------------------------------------------------------
# Step 2: Strip ANSI/VT100 escape sequences
# Removes color codes, cursor movement, bold, etc.
# ------------------------------------------------------------------
strip_ansi() {
    sed -E 's/\x1b\[[0-9;]*[mABCDEFGHJKSTfhilrs]//g; s/\x1b\([A-Z]//g; s/\x1b[=>]//g'
}

# ------------------------------------------------------------------
# Step 3: Normalize Windows paths to Unix format
# C:\Users\foo → /c/Users/foo
# C:/Users/foo → /c/Users/foo
# ------------------------------------------------------------------
normalize_paths() {
    # C:\path\to\file → /c/path/to/file
    sed -E \
        -e 's|([A-Za-z]):\\\\|/\L\1/|g' \
        -e 's|([A-Za-z]):\\|/\L\1/|g' \
        -e 's|([A-Za-z]):/|/\L\1/|g' \
        -e 's|\\\\|/|g' \
        -e 's|\\|/|g'
}

# ------------------------------------------------------------------
# Step 4: Replace timestamps with TIMESTAMP placeholder
# Matches ISO 8601 and common log formats
# ------------------------------------------------------------------
normalize_timestamps() {
    sed -E \
        -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?/TIMESTAMP/g' \
        -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/TIMESTAMP/g'
}

# ------------------------------------------------------------------
# Step 5: Strip trailing whitespace per line
# ------------------------------------------------------------------
strip_trailing_whitespace() {
    sed 's/[[:space:]]*$//'
}

# ------------------------------------------------------------------
# Full normalization pipeline
# ------------------------------------------------------------------
normalize_full() {
    normalize_line_endings | \
    strip_ansi             | \
    normalize_paths        | \
    normalize_timestamps   | \
    strip_trailing_whitespace
}

# ------------------------------------------------------------------
# Execute based on mode
# ------------------------------------------------------------------
run_normalization() {
    case "$MODE" in
        full)        normalize_full ;;
        paths)       normalize_paths ;;
        ansi)        strip_ansi ;;
        timestamps)  normalize_timestamps ;;
        whitespace)  normalize_line_endings | strip_trailing_whitespace ;;
        *)
            echo "Unknown mode: $MODE (valid: full|paths|ansi|timestamps|whitespace)" >&2
            exit 1
            ;;
    esac
}

# ------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------
if [[ -n "$INPUT_FILE" ]]; then
    run_normalization < "$INPUT_FILE"
else
    run_normalization
fi
