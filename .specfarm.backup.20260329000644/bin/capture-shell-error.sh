#!/bin/bash
# capture-shell-error.sh — SpecFarm Shell Error Capture Wrapper
#
# Logs shell errors to .specfarm/justifications.log and checks them against
# nudge rules in rules/nudges/ to surface actionable suggestions.
#
# Usage (source mode):
#   source bin/capture-shell-error.sh
#   capture_shell_error "docker build --no-cache ." 1 "" "Building image"
#
# Usage (standalone mode):
#   bin/capture-shell-error.sh --command "docker build --no-cache ." \
#       --exit-code 1 --stderr "..." --context "Building image"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

JUSTIFICATIONS_LOG="${JUSTIFICATIONS_LOG:-.specfarm/justifications.log}"
SHELL_ERRORS_LOG="${SHELL_ERRORS_LOG:-.specfarm/shell-errors.log}"
NUDGE_RULES_DIR="${NUDGE_RULES_DIR:-$BASE_DIR/rules/nudges}"
NUDGE_QUIET="${NUDGE_QUIET:-true}"

_ensure_dirs() {
    mkdir -p "$(dirname "$JUSTIFICATIONS_LOG")" "$(dirname "$SHELL_ERRORS_LOG")"
}

# _check_nudge_rules COMMAND
# Check a command string against nudge rule patterns and print suggestions.
_check_nudge_rules() {
    local command="$1"
    if [[ ! -d "$NUDGE_RULES_DIR" ]]; then
        return
    fi

    for rule_file in "$NUDGE_RULES_DIR"/*.conf; do
        [[ -f "$rule_file" ]] || continue
        while IFS='|' read -r rule_id pattern message; do
            [[ -z "$rule_id" || "$rule_id" == \#* ]] && continue
            if echo "$command" | grep -qE "$pattern" 2>/dev/null; then
                echo -e "\033[0;33m[NUDGE/$rule_id]: $message\033[0m" >&2
            fi
        done < "$rule_file"
    done
}

# capture_shell_error COMMAND EXIT_CODE [STDERR] [CONTEXT]
# Log a shell error and check for matching nudge rules.
capture_shell_error() {
    local command="$1"
    local exit_code="${2:-1}"
    local stderr="${3:-}"
    local context="${4:-}"

    _ensure_dirs

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

    # Log to shell-errors.log (JSON-compatible single-line entry)
    printf '{"timestamp":"%s","command":"%s","exit_code":%s,"stderr":"%s","context":"%s","commit":"%s"}\n' \
        "$timestamp" \
        "$(echo "$command" | sed 's/"/\\"/g')" \
        "$exit_code" \
        "$(echo "$stderr" | sed 's/"/\\"/g; s/\n/\\n/g')" \
        "$(echo "$context" | sed 's/"/\\"/g')" \
        "$commit_hash" \
        >> "$SHELL_ERRORS_LOG"

    # Log to justifications.log as a shell-error entry
    local rule_id="shell-error-$(echo "$command" | cksum | awk '{print $1}')"
    echo "[$timestamp] RULE=\"$rule_id\" JUSTIFICATION=\"shell-error: exit $exit_code: $command\" COMMIT=\"$commit_hash\"" \
        >> "$JUSTIFICATIONS_LOG"

    # Check nudge rules and surface suggestions
    _check_nudge_rules "$command"
}

# If run directly (not sourced), parse CLI arguments.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command_arg=""
    exit_code_arg="1"
    stderr_arg=""
    context_arg=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --command)    command_arg="$2";    shift 2 ;;
            --exit-code)  exit_code_arg="$2";  shift 2 ;;
            --stderr)     stderr_arg="$2";     shift 2 ;;
            --context)    context_arg="$2";    shift 2 ;;
            --help|-h)
                echo "Usage: capture-shell-error.sh --command CMD --exit-code N [--stderr ERR] [--context CTX]"
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done

    if [[ -z "$command_arg" ]]; then
        echo "Error: --command is required." >&2
        exit 1
    fi

    capture_shell_error "$command_arg" "$exit_code_arg" "$stderr_arg" "$context_arg"
    echo "Shell error captured."
fi
