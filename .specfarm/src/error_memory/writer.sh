#!/bin/bash
# src/error_memory/writer.sh — Error-Memory Persistence writer
# Task T0445: Appends error entries to .specfarm/error-memory.md with deduplication
#
# Usage: bash src/error_memory/writer.sh --category <cat> --message <msg> [--file <path>]
# Schema: [timestamp] ERROR: <category> — <message>  (one entry per line)
# Idempotent: same category+message within 1 hour is not re-added
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default error-memory file (can be overridden for tests via SPECFARM_ROOT or --file)
_default_file() {
    local root="${SPECFARM_ROOT:-$BASE_DIR}"
    echo "${root}/.specfarm/error-memory.md"
}

CATEGORY=""
MESSAGE=""
ERROR_MEMORY_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --category) CATEGORY="$2";          shift 2 ;;
        --message)  MESSAGE="$2";           shift 2 ;;
        --file)     ERROR_MEMORY_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$CATEGORY" || -z "$MESSAGE" ]]; then
    echo "ERROR: --category and --message are required" >&2
    exit 1
fi

[[ -z "$ERROR_MEMORY_FILE" ]] && ERROR_MEMORY_FILE="$(_default_file)"

SPECFARM_DIR="$(dirname "$ERROR_MEMORY_FILE")"
mkdir -p "$SPECFARM_DIR"

# ---- Helpers ----

# Parse ISO-8601 UTC timestamp to epoch seconds (portable: tries date -d, then python3)
_ts_to_epoch() {
    local ts="$1"
    date -u -d "$ts" +%s 2>/dev/null \
        || python3 -c "
import datetime, sys
ts = sys.argv[1]
try:
    dt = datetime.datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$ts" 2>/dev/null \
        || echo 0
}

# Returns 0 (true) if an identical category+message entry was written within 1 hour
_is_duplicate() {
    local cat="$1"
    local msg="$2"
    [[ ! -f "$ERROR_MEMORY_FILE" ]] && return 1

    local epoch_now
    epoch_now=$(date -u +%s 2>/dev/null || echo 0)

    while IFS= read -r line; do
        # Expected format: [YYYY-MM-DDTHH:MM:SSZ] ERROR: <cat> — <msg>
        if [[ "$line" == *"ERROR: ${cat} — ${msg}"* ]]; then
            # Extract the bracketed timestamp
            local ts
            ts=$(echo "$line" | sed -n 's/^\[\([^]]*\)\].*/\1/p' 2>/dev/null || echo "")
            if [[ -n "$ts" ]]; then
                local epoch_entry
                epoch_entry=$(_ts_to_epoch "$ts")
                local diff=$(( epoch_now - epoch_entry ))
                if [[ $diff -lt 3600 ]]; then
                    return 0  # duplicate within 1 hour
                fi
            fi
        fi
    done < "$ERROR_MEMORY_FILE"

    return 1  # not a duplicate
}

# ---- Main ----

if _is_duplicate "$CATEGORY" "$MESSAGE"; then
    echo "SKIP: duplicate error within 1 hour (category=${CATEGORY})" >&2
    exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ENTRY="[${TIMESTAMP}] ERROR: ${CATEGORY} — ${MESSAGE}"

echo "$ENTRY" >> "$ERROR_MEMORY_FILE"
echo "WRITTEN: $ENTRY"
