#!/bin/bash
# justifications-log.sh — SpecFarm Justification Log Writer
# Provides structured logging functions for justification entries.
# Each entry is a single line in the format:
#   [TIMESTAMP] RULE="id" JUSTIFICATION="reason" COMMIT="hash" FILE="path" LINE="n"
#
# Usage: source this file, then call log_justification or justify_rule.

set -euo pipefail

JUSTIFICATIONS_LOG="${JUSTIFICATIONS_LOG:-.specfarm/justifications.log}"

# _ensure_log_dir
# Create the parent directory of JUSTIFICATIONS_LOG if it doesn't exist.
_ensure_log_dir() {
    local dir
    dir="$(dirname "$JUSTIFICATIONS_LOG")"
    mkdir -p "$dir"
}

# log_justification RULE_ID REASON [FILE] [LINE]
# Append a structured justification entry to JUSTIFICATIONS_LOG.
# FILE and LINE are optional context fields.
log_justification() {
    local rule_id="$1"
    local reason="$2"
    local file="${3:-}"
    local line="${4:-}"

    _ensure_log_dir

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local commit_hash
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

    local entry="[$timestamp] RULE=\"$rule_id\" JUSTIFICATION=\"$reason\" COMMIT=\"$commit_hash\""
    [[ -n "$file" ]] && entry="$entry FILE=\"$file\""
    [[ -n "$line" ]] && entry="$entry LINE=\"$line\""

    echo "$entry" >> "$JUSTIFICATIONS_LOG"
}

# has_justification RULE_ID
# Returns 0 if RULE_ID has at least one justification in the log.
has_justification() {
    local rule_id="$1"
    [[ -f "$JUSTIFICATIONS_LOG" ]] && grep -q "RULE=\"$rule_id\"" "$JUSTIFICATIONS_LOG"
}

# list_justifications [RULE_ID]
# List all justification entries, optionally filtered by RULE_ID.
list_justifications() {
    local rule_id="${1:-}"
    if [[ ! -f "$JUSTIFICATIONS_LOG" ]]; then
        echo "No justifications found."
        return
    fi
    if [[ -n "$rule_id" ]]; then
        grep "RULE=\"$rule_id\"" "$JUSTIFICATIONS_LOG" || echo "No justifications for rule: $rule_id"
    else
        cat "$JUSTIFICATIONS_LOG"
    fi
}

# purge_justifications RULE_ID
# Remove all justifications for a given RULE_ID from the log.
purge_justifications() {
    local rule_id="$1"
    if [[ -f "$JUSTIFICATIONS_LOG" ]]; then
        local tmp
        tmp=$(mktemp)
        grep -v "RULE=\"$rule_id\"" "$JUSTIFICATIONS_LOG" > "$tmp" || true
        mv "$tmp" "$JUSTIFICATIONS_LOG"
    fi
}

# If this script is run directly (not sourced), parse CLI arguments.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        log)
            shift
            log_justification "$@"
            echo "Justification recorded."
            ;;
        has)
            shift
            if has_justification "$1"; then
                echo "Justified: $1"
            else
                echo "Not justified: $1"
                exit 1
            fi
            ;;
        list)
            shift
            list_justifications "${1:-}"
            ;;
        purge)
            shift
            purge_justifications "$1"
            echo "Justifications purged for: $1"
            ;;
        help|--help|-h)
            echo "Usage: justifications-log.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  log <rule-id> <reason> [file] [line]  Append a justification entry"
            echo "  has <rule-id>                          Check if a rule has a justification"
            echo "  list [rule-id]                         List justification entries"
            echo "  purge <rule-id>                        Remove all entries for a rule"
            ;;
        *)
            echo "Unknown command: $1"
            exit 1
            ;;
    esac
fi
