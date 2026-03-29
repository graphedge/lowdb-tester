#!/bin/bash
# src/healing/self_healing_executor.sh — SelfHealingExecutor prototype
# Task T0443: Simulates patch+rollback with audit trail (dry-run only for Phase 5 safety)
#
# Usage: bash src/healing/self_healing_executor.sh --file <path> --rule-id <id> --action <type> [--dry-run]
# Contract: SelfHealingExecutor (see 03-contract-api-specs.md)
#
# Actions: suggest | apply_patch
# --dry-run: Log what WOULD happen without modifying files (default for Phase 5 prototype)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
TARGET_FILE=""
RULE_ID=""
ACTION="suggest"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)     TARGET_FILE="$2"; shift 2 ;;
        --rule-id)  RULE_ID="$2"; shift 2 ;;
        --action)   ACTION="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        *)          shift ;;
    esac
done

# ---- Helpers ----

_log_audit() {
    local status="$1"
    local details="$2"
    local rollback_available="$3"

    local audit_dir=".specfarm/audit"
    mkdir -p "$audit_dir"
    local audit_file="$audit_dir/healing-log.ndjson"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Escape details for JSON
    local escaped_details="${details//\\/\\\\}"
    escaped_details="${escaped_details//\"/\\\"}"
    escaped_details="${escaped_details//$'\n'/\\n}"
    escaped_details="${escaped_details//$'\t'/\\t}"
    escaped_details="${escaped_details//$'\r'/}"

    local escaped_file="${TARGET_FILE//\\/\\\\}"
    escaped_file="${escaped_file//\"/\\\"}"
    escaped_file="${escaped_file//$'\t'/\\t}"

    echo "{\"timestamp\":\"${timestamp}\",\"rule_id\":\"${RULE_ID}\",\"action\":\"${ACTION}\",\"file\":\"${escaped_file}\",\"status\":\"${status}\",\"dry_run\":${DRY_RUN},\"rollback_available\":${rollback_available},\"details\":\"${escaped_details}\"}" >> "$audit_file"
}

_suggest_fix() {
    local file="$1"
    local rule_id="$2"

    # Common fix suggestions based on rule patterns
    case "$rule_id" in
        strict-mode|strict_mode)
            echo "Add 'set -euo pipefail' after shebang line"
            ;;
        module-integrity|module_integrity)
            echo "Ensure function is exported: export -f <function_name>"
            ;;
        test-coverage|test_coverage)
            echo "Add unit test for untested function"
            ;;
        *)
            echo "Review rule '$rule_id' and address violation in '$file'"
            ;;
    esac
}

_create_backup() {
    local file="$1"
    local backup_dir=".specfarm/audit/backups"
    mkdir -p "$backup_dir"

    if [[ -f "$file" ]]; then
        local backup_name
        backup_name=$(echo "$file" | tr '/' '_')
        cp "$file" "$backup_dir/${backup_name}.backup"
        return 0
    fi
    return 1
}

# ---- Main ----

main() {
    # Validate inputs
    if [[ -z "$TARGET_FILE" ]]; then
        echo "ERROR: --file is required" >&2
        exit 1
    fi

    if [[ -z "$RULE_ID" ]]; then
        echo "ERROR: --rule-id is required" >&2
        exit 1
    fi

    local suggestion
    suggestion=$(_suggest_fix "$TARGET_FILE" "$RULE_ID")

    case "$ACTION" in
        suggest)
            if $DRY_RUN; then
                echo "DRY-RUN: Would suggest fix for $TARGET_FILE (rule: $RULE_ID)"
                echo "Suggestion: $suggestion"
                _log_audit "suggested" "$suggestion" "false"
            else
                echo "Suggestion: $suggestion"
                _log_audit "suggested" "$suggestion" "false"
            fi
            ;;
        apply_patch)
            if $DRY_RUN; then
                echo "DRY-RUN: Would apply patch to $TARGET_FILE (rule: $RULE_ID)"
                echo "Patch: $suggestion"
                echo "NOTE: File NOT modified (dry-run mode)"
                _log_audit "dry-run-patch" "$suggestion" "true"
            else
                # Create backup before any modification
                if _create_backup "$TARGET_FILE"; then
                    echo "Backup created"
                    _log_audit "backup-created" "Backup of $TARGET_FILE" "true"
                fi

                # Phase 5 prototype: only log, no actual patching in automated mode
                echo "BLOCKED: Auto-patching requires human approval (Phase 5 safety)"
                _log_audit "blocked-needs-approval" "$suggestion" "true"
            fi
            ;;
        *)
            echo "ERROR: Unknown action '$ACTION'. Use 'suggest' or 'apply_patch'" >&2
            _log_audit "error" "Unknown action: $ACTION" "false"
            exit 1
            ;;
    esac
}

main
