#!/bin/bash
# bin/spec-env-brief.sh — Context Scout: Session environment briefing
# Task T0440: Outputs JSON with shell, OS, git status, rules count, error-memory summary
# Usage: bash bin/spec-env-brief.sh [--pretty]
#
# Provides agent handoff context for reliable session startup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source platform detection
source "$BASE_DIR/src/crossplatform/platform-check.sh"

# ---- Helpers ----

_get_shell_info() {
    local shell_name
    shell_name="${SHELL:-unknown}"
    shell_name="$(basename "$shell_name")"
    local shell_version
    shell_version="${BASH_VERSION:-unknown}"
    echo "${shell_name}:${shell_version}"
}

_get_git_info() {
    local branch commit status_clean
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
        commit="$(git rev-parse --short HEAD 2>/dev/null || echo "none")"
        if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
            status_clean="true"
        else
            status_clean="false"
        fi
    else
        branch="none"
        commit="none"
        status_clean="unknown"
    fi
    echo "${branch}|${commit}|${status_clean}"
}

_count_rules() {
    local rules_file=".specfarm/rules.xml"
    if [[ -f "$rules_file" ]]; then
        # Count <rule> elements
        local count
        count=$(grep -c '<rule ' "$rules_file" 2>/dev/null || echo "0")
        echo "$count"
    else
        echo "0"
    fi
}

_get_error_memory() {
    local error_file=".specfarm/error-memory.md"
    local shell_errors=".specfarm/shell-errors.log"
    local error_count=0
    local last_error="none"

    if [[ -f "$shell_errors" ]]; then
        error_count=$(wc -l < "$shell_errors" 2>/dev/null | tr -d ' ')
        last_error=$(tail -1 "$shell_errors" 2>/dev/null | head -c 200 || echo "none")
    fi

    if [[ -f "$error_file" ]]; then
        local mem_count
        mem_count=$(grep -c '^- ' "$error_file" 2>/dev/null || echo "0")
        error_count=$((error_count + mem_count))
    fi

    echo "${error_count}|${last_error}"
}

# ---- Main ----

main() {
    local pretty=false
    [[ "${1:-}" == "--pretty" ]] && pretty=true

    # Gather data
    local shell_info os_info git_info rules_count error_info timestamp
    shell_info=$(_get_shell_info)
    os_info=$(detect_platform)
    git_info=$(_get_git_info)
    rules_count=$(_count_rules)
    error_info=$(_get_error_memory)
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Parse compound fields
    local shell_name shell_version
    shell_name="${shell_info%%:*}"
    shell_version="${shell_info#*:}"

    local git_branch git_commit git_clean
    git_branch="${git_info%%|*}"
    local git_rest="${git_info#*|}"
    git_commit="${git_rest%%|*}"
    git_clean="${git_rest#*|}"

    local error_count last_error
    error_count="${error_info%%|*}"
    last_error="${error_info#*|}"

    # Sanitize last_error for JSON (escape quotes and backslashes)
    last_error="${last_error//\\/\\\\}"
    last_error="${last_error//\"/\\\"}"
    last_error="${last_error//$'\n'/\\n}"
    last_error="${last_error//$'\r'/}"

    # Normalize git_clean to valid JSON boolean
    local git_clean_json
    case "$git_clean" in
        true)  git_clean_json="true" ;;
        false) git_clean_json="false" ;;
        *)     git_clean_json="null" ;;
    esac

    # Build JSON output
    local json
    json=$(cat <<EOF
{"timestamp":"${timestamp}","shell":"${shell_name}","shell_version":"${shell_version}","os":"${os_info}","git":{"branch":"${git_branch}","commit":"${git_commit}","clean":${git_clean_json}},"rules":{"count":${rules_count},"file":".specfarm/rules.xml"},"error_memory":{"count":${error_count},"last":"${last_error}"}}
EOF
)

    if $pretty && command -v python3 >/dev/null 2>&1; then
        echo "$json" | python3 -m json.tool
    else
        echo "$json"
    fi
}

main "$@"
