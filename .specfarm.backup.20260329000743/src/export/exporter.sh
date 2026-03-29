#!/bin/bash
# Exporter logic for SpecFarm

EXPORTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$EXPORTER_DIR/../.." && pwd)"

source "$EXPORTER_DIR/xml_builder.sh"
source "$EXPORTER_DIR/inference_engine.sh"

export_rules() {
    local rules_output=".specfarm/rules.xml"
    local constitution_file=".specify/memory/constitution.md"
    
    # Initialize output
    rm -f "$rules_output"
    
    {
    init_xml
    
    # Mode from config
    local mode=$(grep "^PHASE_MODE=" .specfarm/config | cut -d'=' -f2- | tr -d '"' || echo "loose")
    add_phase_constraints "$mode"
    
    # 1. Parse Constitution for core principles
    if [[ -f "$constitution_file" ]]; then
        # Simple extraction for now
        grep "^### [IVX]\+\." "$constitution_file" | while read -r line; do
            local name=$(echo "$line" | sed 's/### //')
            local id=$(echo "$line" | awk '{print $2}' | tr -d '.')
            
            start_rule "CP-$id" "true" "" "1.0"
            add_description "$name"
            add_signature "keyword" "CP-$id"
            end_rule
        done
    fi
    
    # 2. Parse Tasks for phase constraints and certainty
    if [[ -d specs ]]; then
        # Use find but avoid subshells in pipes if possible
        for task_file in $(find specs -name "tasks*.md"); do
            # Use while loop with file redirection to avoid pipe subshell issues
            while read -r line; do
                local task_id=$(echo "$line" | sed -E 's/^- \[ \] ([A-Z0-9]+).*/\1/')
                local task_desc=$(echo "$line" | sed -E 's/^- \[ \] [A-Z0-9]+ (.*)/\1/')
                
                local score=$(score_certainty "$task_desc")
                
                start_rule "TASK-$task_id" "false" "" "$score"
                add_description "$task_desc"
                add_signature "keyword" "$task_id"
                end_rule
            done < <(grep -E "^- \[ \] " "$task_file")
        done
    fi
    
    close_xml
    } > "$rules_output"
    
    echo "Rules exported successfully to $rules_output"
}
