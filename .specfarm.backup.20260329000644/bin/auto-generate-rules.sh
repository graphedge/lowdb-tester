#!/bin/bash
# bin/auto-generate-rules.sh - Auto-generate enforcement rules from shell-error patterns
# T018: Pre-commit hook rule-generation
# Reads shell-errors.log, groups patterns, auto-generates new rules if pattern occurs 2+ times
# Usage: auto-generate-rules.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SPECFARM_HOME="${SPECFARM_HOME:-.specfarm}"
SHELL_ERRORS_LOG="${SPECFARM_HOME}/shell-errors.log"
RULES_FILE="${SPECFARM_HOME}/rules.xml"
NUDGE_CONF="${BASE_DIR}/rules/nudges/ci-antipatterns.conf"
DRY_RUN="${1:-}"

# Helper: Validate rules XML structure
_validate_rules_xml() {
    local file="$1"
    if command -v xmlstarlet &>/dev/null; then
        xmlstarlet val -w "$file" >/dev/null 2>&1
    else
        # Fallback: basic check
        grep -q "<specfarm>" "$file" && grep -q "</specfarm>" "$file"
    fi
}

# Helper: Generate rule from nudge config
_generate_rule_from_pattern() {
    local pattern="$1"
    local count="$2"
    
    if [[ ! -f "$NUDGE_CONF" ]]; then
        echo "<!-- Pattern: $pattern ($count occurrences) -->"
        return 0
    fi
    
    # Get details from nudge config
    local config_line=$(grep "^$pattern|" "$NUDGE_CONF" || true)
    if [[ -z "$config_line" ]]; then
        echo "<!-- Unknown pattern: $pattern -->"
        return 0
    fi
    
    IFS='|' read -r pat category severity message <<< "$config_line"
    
    # Generate rule XML
    cat <<EOF
  <rule id="$pattern" global="true" certainty="0.$((10 - (count > 5 ? 5 : count)))">
    <description>$message</description>
    <signature type="keyword">$pattern</signature>
  </rule>
EOF
}

# Main: Extract patterns and generate rules
main() {
    [[ ! -f "$SHELL_ERRORS_LOG" ]] && { echo "No shell-errors.log found"; exit 0; }
    [[ ! -f "$RULES_FILE" ]] && { echo "No rules.xml found"; exit 1; }
    
    # Extract and count patterns
    local patterns=$(grep -o '"pattern":"[^"]*"' "$SHELL_ERRORS_LOG" 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -rn)
    
    local new_rules=""
    local rules_generated=0
    
    # For each pattern with 2+ occurrences
    while read count pattern; do
        [[ -z "$pattern" ]] && continue
        
        # Only auto-generate rules for patterns with 2+ occurrences
        [[ "$count" -lt 2 ]] && continue
        
        # Check if rule already exists
        if grep -q "id=\"$pattern\"" "$RULES_FILE"; then
            echo "ℹ️  Rule already exists: $pattern (count: $count)"
        else
            echo "✓ New rule to generate: $pattern (count: $count)"
            
            local new_rule
            new_rule=$(_generate_rule_from_pattern "$pattern" "$count")
            new_rules+="$new_rule"$'\n'
            rules_generated=$((rules_generated + 1))
        fi
    done <<< "$patterns"
    
    if [[ "$rules_generated" -eq 0 ]]; then
        echo "No new rules to generate"
        exit 0
    fi
    
    # Add new rules to rules.xml (insert before closing tag)
    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        echo ""
        echo "=== DRY RUN: Would add the following rules ==="
        echo "$new_rules"
        echo "=== End dry-run ==="
    else
        # Create backup
        cp "$RULES_FILE" "${RULES_FILE}.backup"
        
        # Insert new rules before closing tag
        local temp_file=$(mktemp)
        sed '/<\/specfarm>/i'"$(printf '%s\n' "$new_rules" | sed 's/[\/&]/\\&/g')" "$RULES_FILE" > "$temp_file"
        mv "$temp_file" "$RULES_FILE"
        
        # Validate new rules file
        if _validate_rules_xml "$RULES_FILE"; then
            echo "✓ Added $rules_generated new rules to $RULES_FILE"
            git add "$RULES_FILE" 2>/dev/null || true
        else
            echo "✗ Validation failed! Restoring backup."
            mv "${RULES_FILE}.backup" "$RULES_FILE"
            exit 1
        fi
    fi
}

main "$@"
