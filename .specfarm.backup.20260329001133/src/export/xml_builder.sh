#!/bin/bash

# XML Builder for SpecFarm rules.xml

init_xml() {
    local version="1.0"
    echo "<?xml version="1.0" encoding="UTF-8"?>"
    echo "<specfarm version="$version">"
}

add_phase_constraints() {
    local mode=$1
    if [[ "$mode" != "strict" && "$mode" != "loose" ]]; then
        echo "<!-- Warning: Invalid mode '$mode', defaulting to loose -->" >&2
        mode="loose"
    fi
    echo "  <phase-constraints mode=\"$mode\">"
    echo "    <!-- Inferred from SpecKit tasks -->"
    echo "  </phase-constraints>"
}

start_rule() {
    local id=$1
    local global=$2
    local folder=$3
    local certainty=$4

    if [[ -z "$id" ]]; then
        echo "Error: Rule ID is required" >&2
        return 1
    fi

    local attrs="id=\"$id\""
    [[ "$global" == "true" ]] && attrs="$attrs global=\"true\""
    [[ -n "$folder" ]] && attrs="$attrs folder=\"$folder\""

    # Validate certainty is a float between 0 and 1
    if [[ -n "$certainty" ]]; then
        if ! [[ "$certainty" =~ ^[0-9](\.[0-9]+)?$ ]] || (( $(echo "$certainty > 1.0" | bc -l) )); then
            echo "<!-- Warning: Invalid certainty '$certainty' for rule '$id', defaulting to 1.0 -->" >&2
            certainty="1.0"
        fi
        attrs="$attrs certainty=\"$certainty\""
    fi

    echo "  <rule $attrs>"
}

add_description() {
    echo "    <description>$1</description>"
}

add_signature() {
    local type=$1
    local value=$2
    echo "    <signature type="$type">$value</signature>"
}

end_rule() {
    echo "  </rule>"
}

close_xml() {
    echo "</specfarm>"
}
