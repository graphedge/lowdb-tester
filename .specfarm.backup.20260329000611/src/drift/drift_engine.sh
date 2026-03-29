#!/bin/bash
# Drift Engine logic in Bash

parse_rules() {
    local rules_file="$1"
    local filter_folder="$2"
    local openspec_mode_enabled="$3" # New parameter for openspec mode

    if [[ "$openspec_mode_enabled" == "true" ]]; then
        if ! command -v xmlstarlet >/dev/null; then
            echo "Error: xmlstarlet required for OpenSpec mode. Install via apt/brew/pkg/etc." >&2
            return 1
        fi

        # Validate XML first
        local xml_validation_output
        if ! xml_validation_output=$(xmlstarlet val "$rules_file" 2>&1); then
            echo "Error: rules.xml is malformed. Validation output:\n$xml_validation_output" >&2
            return 1
        fi
        
        # Extract rules using xmlstarlet
        xmlstarlet sel -t -m "//rule" \
            -v "concat(@id, '|')" \
            -v "concat(substring((@global='true'), 1, 1), '|')" \
            -v "concat(@folder, '|')" \
            -v "concat(concat(string(@certainty), substring('1.0', 1, number(not(@certainty)) * 3)), '|')" \
            -v "concat(normalize-space(description), '|')" \
            -v "concat(concat(string(@type), substring('keyword', 1, number(not(@type)) * 7)), '|')" \
            -v "normalize-space(signature)" \
            -n "$rules_file" | while IFS="|" read -r id global folder certainty desc sig_type sig_val; do
            
            # Filter rules based on folder and global attributes, mimicking awk's logic
            show=0
            if [[ -z "$filter_folder" ]]; then
                show=1
            elif [[ "$global" == "t" ]]; then # xmlstarlet outputs 'true' as 't' if used in boolean context
                show=1
            elif [[ -n "$folder" ]]; then
                # Split folder by '|' and check if filter_folder is in it
                IFS='|' read -ra folders <<< "$folder"
                for f in "${folders[@]}"; do
                    if [[ "$f" == "$filter_folder" ]]; then
                        show=1
                        break
                    fi
                done
            fi

            if [[ "$show" -eq 1 ]]; then
                # Reconstruct the output string in the format expected by run_drift_check
                if [[ "$global" == "t" ]]; then
                    global_output="true"
                else
                    global_output="false"
                fi
                
                echo "${id}|${global_output}|${folder}|${certainty}|${desc}|${sig_type}|${sig_val}"
            fi
        done
    else # Fallback to gawk if OpenSpec mode is not enabled
        local awk_cmd=""
        if command -v gawk >/dev/null; then
            awk_cmd="gawk"
        elif command -v awk >/dev/null; then
            awk_cmd="awk"
        else
            echo "Error: Neither gawk nor awk found. One is required for basic rule parsing. Install via apt/brew/pkg/etc." >&2
            return 1
        fi
        
        # Gawk processing. If it returns non-zero, it means there's a problem.
        # But gawk is lenient with malformed XML.
        # So we'll run it, capture its output, and check if it produced valid lines.
        # If gawk's output is empty, and it should have parsed rules, then it's an error.
        
        local gawk_raw_output
        if ! gawk_raw_output=$("$awk_cmd" -v target_folder="$filter_folder" '
        BEGIN {
            RS="<rule ";
        }
        NR > 1 {
            match($0, /([^>]*)>(.*)/, parts);
            attrs = parts[1];
            content = parts[2];
            
            id=""; global="false"; folder=""; certainty="1.0";
            if (match(attrs, /id="([^"]+)"/, m)) { id=m[1]; }
            if (attrs ~ /global="true"/) { global="true"; }
            if (match(attrs, /folder="([^"]+)"/, m)) { folder=m[1]; }
            if (match(attrs, /certainty="([^"]+)"/, m)) { certainty=m[1]; }
            
            show = 0;
            if (target_folder == "") {
                show = 1;
            } else {
                if (global == "true") {
                    show = 1;
                } else if (folder != "") {
                    split(folder, folders, "|");
                    for (i in folders) {
                        if (folders[i] == target_folder) {
                            show = 1;
                            break;
                        }
                    }
                }
            }
            
            if (show) {
                desc=""; sig_type="keyword"; sig_val="";
                if (match(content, /<description>([^<]*)<\/description>/, m)) {
                    desc=m[1];
                    gsub(/\n/, " ", desc);
                }
                if (match(content, /<signature[^>]*>([^<]*)<\/signature>/, m)) {
                    sig_val=m[1];
                    gsub(/\n/, " ", sig_val);
                    if (match(content, /<signature type="([^"]+)"/, t)) {
                        sig_type=t[1];
                    }
                }
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", sig_val);
                print id "|" global "|" folder "|" certainty "|" desc "|" sig_type "|" sig_val;
            }
        }
        ' "$rules_file" 2>&1); then # Capture gawk's stderr too
            echo "Error: Gawk parsing failed for rules.xml. Check its structure. Gawk output:\n$gawk_raw_output" >&2
            return 1
        fi
        echo "$gawk_raw_output"
    fi
}

detect_shell_error_nudges() {
    local shell_errors_log=".specfarm/shell-errors.log"
    local nudge_conf="rules/nudges/ci-antipatterns.conf"
    
    [[ ! -f "$shell_errors_log" ]] && return 0
    [[ ! -f "$nudge_conf" ]] && return 0
    
    # Count occurrences of each pattern
    local pattern_counts=""
    pattern_counts=$(grep -o '"pattern":"[^"]*"' "$shell_errors_log" 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -rn)
    
    # For each pattern with 2+ occurrences, show nudge suggestion
    echo "$pattern_counts" | while read count pattern; do
        [[ -z "$pattern" ]] && continue
        [[ "$count" -lt 2 ]] && continue
        
        # Get nudge message from config
        local nudge_msg=$(grep "^$pattern|" "$nudge_conf" 2>/dev/null | cut -d'|' -f4)
        [[ -n "$nudge_msg" ]] && echo "💡 Nudge ($count occurrences): $nudge_msg"
    done
}

run_drift_check() {
    local rules_file=".specfarm/rules.xml"
    local filter_folder="$1"
    local export_format="${2:-text}"
    local openspec_mode_enabled="${3:-}" # New parameter (optional)
    local justifications_file=".specfarm/justifications.log"
    
    if [[ ! -f "$rules_file" ]]; then
        echo "Error: rules.xml not found."
        return 1
    fi

    if [[ "$export_format" == "markdown" ]]; then
        echo "## SpecFarm Drift Report"
        [[ -n "$filter_folder" ]] && echo "Scope: \`$filter_folder\` (+ global rules)"
        echo ""
        echo "| Rule ID | Score | Status | Description |"
        echo "| :--- | :--- | :--- | :--- |"
    else
        echo "SpecFarm Drift Report"
        [[ -n "$filter_folder" ]] && echo "Scope: $filter_folder (+ global rules)"
        echo ""
        printf "%-30s | %-6s | %-10s\n" "Rule ID" "Score" "Status"
        echo "-------------------------------|--------|-----------"
    fi

    local total_score=0
    local rule_count=0
    
    # Load justifications into an array-like string for easier checking
    local justifications=""
    if [[ -f "$justifications_file" ]]; then
        justifications=$(cat "$justifications_file")
    fi

    # Read parse_rules output into a temporary file
    local temp_rules=$(mktemp)
    if ! parse_rules "$rules_file" "$filter_folder" "$openspec_mode_enabled" > "$temp_rules"; then
        echo "Error: Failed to parse rules from $rules_file. Check XML format." >&2
        rm -f "$temp_rules"
        return 1
    fi

    while IFS="|" read -r id global folder certainty desc sig_type sig_val; do
        [[ -z "$id" ]] && continue
        rule_count=$((rule_count + 1))
        
        local match_count=0
        if [[ -n "$sig_val" ]]; then
            # Unescape the regex pattern as process-shell-errors escapes it.
            local unescaped_sig_val=$(echo "$sig_val" | sed 's/\\//g')
            # Search only source directories to avoid matching diff/artifact files
            local _search_dirs=()
            for _d in src bin scripts rules; do
                [[ -d "$_d" ]] && _search_dirs+=("$_d")
            done
            if [[ ${#_search_dirs[@]} -gt 0 ]]; then
                match_count=$(grep -rE "$unescaped_sig_val" "${_search_dirs[@]}" 2>/dev/null | wc -l)
            fi
        fi
        
        local score="0.00"
        local status="DRIFT"
        
        if [[ "$match_count" -gt 0 ]]; then
            score="1.00"
            status="PASS" # Tentative status if match found
        fi
        
        # Check justifications - simplified check
        if [[ -n "$justifications" ]] && echo "$justifications" | grep -q "RULE=\"$id\""; then
            status="JUSTIFIED" # Overrides PASS if justified
            score="1.00" # Adherence is 100% if justified
        fi

        # Now print using the final status and score
        if [[ "$export_format" == "markdown" ]]; then
            # Escape pipes in description
            local safe_desc=$(echo "$desc" | sed 's/|/\\|/g')
            echo "| $id | $score | $status | $safe_desc |"
        else
            printf "%-30s | %-6s | %-10s\n" "$id" "$score" "$status"
        fi
        
        if [[ "$status" == "PASS" || "$status" == "JUSTIFIED" ]]; then
            # NOTE: This part might need re-evaluation if DRIFT status should also contribute to score.
            # For now, adherence is only calculated based on PASS/JUSTIFIED.
            # If status is DRIFT (after our re-labeling), score remains 0.00, and total_score is not incremented.
            total_score=$((total_score + 100))
        fi
        
    done < "$temp_rules"
    
    rm -f "$temp_rules"

    if [[ "$export_format" == "markdown" ]]; then
        echo ""
        if [[ "$rule_count" -gt 0 ]]; then
            local adherence=$((total_score / rule_count))
            echo "**TOTAL ADHERENCE: ${adherence}%**"
        else
            echo "_No rules found for this scope._"
        fi
    else
        echo "-------------------------------|--------|-----------"
        if [[ "$rule_count" -gt 0 ]]; then
            local adherence=$((total_score / rule_count))
            echo "TOTAL ADHERENCE: ${adherence}%"
        else
            echo "No rules found for this scope."
        fi
    fi
    
    # Display shell-error nudge suggestions
    echo ""
    detect_shell_error_nudges
}
