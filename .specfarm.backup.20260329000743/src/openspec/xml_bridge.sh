#!/bin/bash
# xml_bridge.sh — SpecFarm OpenSpec XML Bridge
# Provides graceful XML parsing that ignores unknown elements and maps
# OpenSpec-specific tags to SpecFarm-compatible rule entries.

# Usage:
#   source .specfarm/src/openspec/xml_bridge.sh
#   xml_bridge_parse_rules <rules_file> [filter_folder]

BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$BRIDGE_DIR/../.." && pwd)"

# Default tag mapping config
TAG_MAPPING_CONF="${OPENSPEC_TAG_MAPPING:-$BASE_DIR/src/openspec/tag-mapping.conf}"

# _load_tag_mappings
# Loads tag->mapped-type mappings from config into the TAG_MAP associative array.
declare -A TAG_MAP

_load_tag_mappings() {
    TAG_MAP=()
    if [[ ! -f "$TAG_MAPPING_CONF" ]]; then
        return
    fi
    while IFS='=' read -r from_tag to_tag; do
        # Skip blank lines and comments
        [[ -z "$from_tag" || "$from_tag" == \#* ]] && continue
        from_tag="${from_tag// /}"
        to_tag="${to_tag// /}"
        TAG_MAP["$from_tag"]="$to_tag"
    done < "$TAG_MAPPING_CONF"
}

# _is_known_element TAG
# Returns 0 if TAG is a known SpecFarm element or mapped to one.
_is_known_element() {
    local tag="$1"
    local known_elements=("specfarm-rules" "specfarm" "rule" "description" "signature"
                          "phase-constraints" "phase" "meta")
    for elem in "${known_elements[@]}"; do
        [[ "$tag" == "$elem" ]] && return 0
    done
    # Check tag map
    [[ -n "${TAG_MAP[$tag]+_}" ]] && return 0
    return 1
}

# xml_bridge_strip FILE
# Strip unknown XML elements from FILE and write clean XML to stdout.
# Known elements are preserved; unknown elements are silently removed.
xml_bridge_strip() {
    local file="$1"
    _load_tag_mappings

    if [[ ! -f "$file" ]]; then
        echo "Error: xml_bridge_strip: file not found: $file" >&2
        return 1
    fi

    # Build known element list for awk
    local known_list="specfarm-rules specfarm rule description signature phase-constraints phase meta"
    for key in "${!TAG_MAP[@]}"; do
        local mapped="${TAG_MAP[$key]}"
        if [[ "$mapped" == "rule" || "$mapped" == "meta" ]]; then
            known_list="$known_list $key"
        fi
    done

    awk -v known="$known_list" '
    BEGIN {
        n = split(known, ka, " ");
        for (i=1; i<=n; i++) allowed[ka[i]] = 1;
        skip = 0;
        skip_tag = "";
    }
    {
        line = $0;

        # XML declaration and processing instructions always pass through
        if (line ~ /^[[:space:]]*<\?/ || line ~ /^[[:space:]]*<!--/) {
            if (!skip) print line;
            next;
        }

        # Closing tag: check if we are skipping this element
        if (line ~ /^[[:space:]]*<\//) {
            tag = line; gsub(/^[[:space:]]*<\//, "", tag); gsub(/>.*/, "", tag);
            gsub(/[[:space:]]/, "", tag);
            if (skip && tag == skip_tag) {
                skip = 0; skip_tag = "";
            } else if (!skip) {
                print line;
            }
            next;
        }

        # Opening tag or self-closing: extract tag name
        if (line ~ /^[[:space:]]*<[^!?]/) {
            tag = line; gsub(/^[[:space:]]*</, "", tag);
            gsub(/[ \/>].*/, "", tag);
            gsub(/[[:space:]]/, "", tag);

            if (tag in allowed) {
                if (!skip) print line;
            } else {
                # Unknown element: skip until its closing tag (unless self-closing)
                if (line !~ />$/ && line !~ /\/>/) {
                    skip = 1; skip_tag = tag;
                }
                # Self-closing unknown elements are simply dropped
            }
            next;
        }

        # Text content or other lines
        if (!skip) print line;
    }
    ' "$file"
}

# xml_bridge_map_tags FILE
# Rewrite OpenSpec-specific tags to their SpecFarm equivalents and write to stdout.
# e.g., <soft-rule id="X"> becomes <rule id="X"> when soft-rule=rule in the mapping.
xml_bridge_map_tags() {
    local file="$1"
    _load_tag_mappings

    if [[ ! -f "$file" ]]; then
        echo "Error: xml_bridge_map_tags: file not found: $file" >&2
        return 1
    fi

    local content
    content=$(cat "$file")

    for from_tag in "${!TAG_MAP[@]}"; do
        local to_tag="${TAG_MAP[$from_tag]}"
        # Replace opening tags: <soft-rule ...> -> <rule ...>
        content=$(echo "$content" | sed "s|<${from_tag}\([[:space:]][^>]*\)>|<${to_tag}\1>|g; \
                                         s|<${from_tag}>|<${to_tag}>|g; \
                                         s|</${from_tag}>|</${to_tag}>|g")
    done

    echo "$content"
}

# xml_bridge_parse_rules FILE [FILTER_FOLDER]
# Parse a rules XML file with graceful handling of unknown elements.
# Applies tag mapping before parsing, then strips remaining unknowns.
# Outputs lines in the format: ID|GLOBAL|FOLDER|CERTAINTY|DESC|SIG_TYPE|SIG_VAL
xml_bridge_parse_rules() {
    local rules_file="$1"
    local filter_folder="${2:-}"

    if [[ ! -f "$rules_file" ]]; then
        echo "Error: rules file not found: $rules_file" >&2
        return 1
    fi

    # Apply tag mapping first, then strip unknown elements
    local tmp_mapped tmp_stripped
    tmp_mapped=$(mktemp)
    tmp_stripped=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f \"$tmp_mapped\" \"$tmp_stripped\"" RETURN

    xml_bridge_map_tags "$rules_file" > "$tmp_mapped"
    xml_bridge_strip "$tmp_mapped" > "$tmp_stripped"

    # Now parse using the same awk logic as drift_engine.sh but from the cleaned file
    gawk -v target_folder="$filter_folder" '
    BEGIN {
        RS="<rule ";
    }
    NR > 1 {
        match($0, /([^>]*)>(.*)/, parts);
        attrs = parts[1];
        content = parts[2];

        id=""; global="false"; folder=""; certainty="1.0";
        if (match(attrs, /id="([^"]+)"/, m))         { id=m[1]; }
        if (attrs ~ /global="true"/)                  { global="true"; }
        if (match(attrs, /folder="([^"]+)"/, m))      { folder=m[1]; }
        if (match(attrs, /certainty="([^"]+)"/, m))   { certainty=m[1]; }

        show = 0;
        if (target_folder == "") {
            show = 1;
        } else {
            if (global == "true") {
                show = 1;
            } else if (folder != "") {
                split(folder, folders, "|");
                for (i in folders) {
                    if (folders[i] == target_folder) { show = 1; break; }
                }
            }
        }

        if (show) {
            desc=""; sig_type="keyword"; sig_val="";
            if (match(content, /<description>([^<]*)<\/description>/, m)) {
                desc=m[1]; gsub(/\n/, " ", desc);
            }
            if (match(content, /<signature[^>]*>([^<]*)<\/signature>/, m)) {
                sig_val=m[1]; gsub(/\n/, " ", sig_val);
                if (match(content, /<signature type="([^"]+)"/, t)) sig_type=t[1];
            }
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", sig_val);
            print id "|" global "|" folder "|" certainty "|" desc "|" sig_type "|" sig_val;
        }
    }
    ' "$tmp_stripped"
}
