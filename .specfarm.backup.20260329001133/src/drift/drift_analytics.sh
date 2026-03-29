#!/bin/bash
# src/drift/drift_analytics.sh — DriftAnalyticsProvider: NDJSON/JSON drift report export
# Task T0442: Exports drift metrics in NDJSON streaming or JSON summary format
#
# Usage: bash src/drift/drift_analytics.sh --format ndjson|json-summary [--scope <path>]
# Contract: GET /api/drift-report (see 03-contract-api-specs.md)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
FORMAT="ndjson"
SCOPE="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format) FORMAT="$2"; shift 2 ;;
        --scope)  SCOPE="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

# ---- Helpers ----

_parse_rules_for_analytics() {
    local rules_file=".specfarm/rules.xml"
    if [[ ! -f "$rules_file" ]]; then
        return
    fi

    # Extract rule entries using gawk or awk
    local awk_cmd="gawk"
    command -v gawk >/dev/null 2>&1 || awk_cmd="awk"

    # Parse rule id, signature, severity, phase from XML
    $awk_cmd '
    /<rule / {
        id=""; sig=""; sev="advisory"; ph="1"
        if (match($0, /id="([^"]*)"/, m)) id=m[1]
        if (match($0, /severity="([^"]*)"/, m)) sev=m[1]
        if (match($0, /phase="([^"]*)"/, m)) ph=m[1]
    }
    /<signature>/ {
        gsub(/.*<signature>/, ""); gsub(/<\/signature>.*/, "")
        sig=$0
    }
    /<\/rule>/ {
        if (id != "") print id "|" sig "|" sev "|" ph
    }
    ' "$rules_file"
}

_check_rule_status() {
    local signature="$1"
    local scope="$2"

    if [[ -z "$signature" ]]; then
        echo "unknown"
        return
    fi

    # Search for signature in scope, excluding non-source dirs
    if grep -rq --include="*.sh" --include="*.bash" --include="*.py" --include="*.js" \
        -e "$signature" "$scope" 2>/dev/null; then
        echo "pass"
    else
        echo "drift"
    fi
}

_is_justified() {
    local rule_id="$1"
    local just_file=".specfarm/justifications.log"
    if [[ -f "$just_file" ]] && grep -q "$rule_id" "$just_file" 2>/dev/null; then
        echo "true"
        return
    fi
    echo "false"
}

# ---- Output Generators ----

_emit_ndjson() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    while IFS='|' read -r rule_id signature severity phase; do
        [[ -z "$rule_id" ]] && continue

        local status
        status=$(_check_rule_status "$signature" "$SCOPE")

        local justified
        justified=$(_is_justified "$rule_id")

        if [[ "$status" == "drift" && "$justified" == "true" ]]; then
            status="justified"
        fi

        # Escape signature for JSON
        local escaped_sig="${signature//\\/\\\\}"
        escaped_sig="${escaped_sig//\"/\\\"}"
        escaped_sig="${escaped_sig//$'\t'/\\t}"
        escaped_sig="${escaped_sig//$'\n'/\\n}"
        escaped_sig="${escaped_sig//$'\r'/}"

        echo "{\"timestamp\":\"${timestamp}\",\"rule_id\":\"${rule_id}\",\"signature\":\"${escaped_sig}\",\"severity\":\"${severity}\",\"phase\":\"${phase}\",\"status\":\"${status}\",\"scope\":\"${SCOPE}\"}"
    done < <(_parse_rules_for_analytics)
}

_emit_json_summary() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local report_id="drift-$(date -u +"%Y-%m-%d")"

    local total=0
    local passed=0
    local drifted=0
    local justified=0

    while IFS='|' read -r rule_id signature severity phase; do
        [[ -z "$rule_id" ]] && continue
        total=$((total + 1))

        local status
        status=$(_check_rule_status "$signature" "$SCOPE")

        local is_justified
        is_justified=$(_is_justified "$rule_id")

        if [[ "$status" == "pass" ]]; then
            passed=$((passed + 1))
        elif [[ "$is_justified" == "true" ]]; then
            justified=$((justified + 1))
        else
            drifted=$((drifted + 1))
        fi
    done < <(_parse_rules_for_analytics)

    local adherence_pct="100"
    if [[ "$total" -gt 0 ]]; then
        adherence_pct=$(awk "BEGIN{printf \"%.1f\", (($passed + $justified) / $total) * 100}")
    fi

    cat <<EOF
{"report_id":"${report_id}","generated_at":"${timestamp}","scope":"${SCOPE}","total_rules":${total},"passed":${passed},"drifted":${drifted},"justified":${justified},"adherence_pct":${adherence_pct}}
EOF
}

# ---- Main ----

case "$FORMAT" in
    ndjson)
        _emit_ndjson
        ;;
    json-summary)
        _emit_json_summary
        ;;
    *)
        echo "ERROR: Unknown format '$FORMAT'. Use 'ndjson' or 'json-summary'" >&2
        exit 1
        ;;
esac
