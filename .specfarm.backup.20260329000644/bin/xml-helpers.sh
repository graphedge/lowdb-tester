#!/bin/bash
# xml-helpers.sh — SpecFarm XML helper wrappers
# Provides safe XML querying and transformation using xmlstarlet or awk fallback.
# Usage: source this file or call functions directly.

set -euo pipefail

# Check whether xmlstarlet is available
_xml_has_xmlstarlet() {
    command -v xmlstarlet >/dev/null 2>&1
}

# xml_get_attr FILE XPATH ATTR
# Extract a single attribute value from the first matching element.
# Example: xml_get_attr rules.xml "//rule[@id='R01']" "certainty"
xml_get_attr() {
    local file="$1" xpath="$2" attr="$3"
    if _xml_has_xmlstarlet; then
        xmlstarlet sel -t -v "${xpath}/@${attr}" "$file" 2>/dev/null || echo ""
    else
        # awk fallback: return first occurrence of attr="value"
        grep -o "${attr}=\"[^\"]*\"" "$file" | head -1 | cut -d'"' -f2 || echo ""
    fi
}

# xml_get_text FILE XPATH
# Extract text content of the first matching element.
# Example: xml_get_text rules.xml "//rule[@id='R01']/description"
xml_get_text() {
    local file="$1" xpath="$2"
    if _xml_has_xmlstarlet; then
        xmlstarlet sel -t -v "$xpath" "$file" 2>/dev/null || echo ""
    else
        local tag
        tag=$(echo "$xpath" | sed 's|.*/||; s|\[.*||')
        sed -n "/<${tag}>/,/<\/${tag}>/s|.*<${tag}>\(.*\)<\/${tag}>.*|\1|p" "$file" | head -1 || echo ""
    fi
}

# xml_count FILE XPATH
# Count matching elements.
# Example: xml_count rules.xml "//rule"
xml_count() {
    local file="$1" xpath="$2"
    if _xml_has_xmlstarlet; then
        xmlstarlet sel -t -v "count(${xpath})" "$file" 2>/dev/null || echo "0"
    else
        local tag
        tag=$(echo "$xpath" | sed 's|.*/||; s|\[.*||')
        grep -c "<${tag}" "$file" 2>/dev/null || echo "0"
    fi
}

# xml_strip_unknown FILE KNOWN_ELEMENTS...
# Remove elements that are not in the known list and write to stdout.
# Uses awk fallback when xmlstarlet is unavailable.
# Example: xml_strip_unknown rules.xml rule description signature
xml_strip_unknown() {
    local file="$1"
    shift
    local known=("$@")

    if _xml_has_xmlstarlet; then
        # Build an XPath expression deleting unknown top-level elements
        local del_expr=""
        # We delete all child elements of the root that are NOT in $known
        # shellcheck disable=SC2001
        del_expr=$(printf "%s\n" "${known[@]}" | \
            awk '{printf "local-name() != \"%s\"", $0; if (NR>1) printf " and "; else printf ""}' | \
            sed 's/ and local-name/\nand local-name/g' | paste -sd ' ')
        xmlstarlet ed --delete "//*[${del_expr}]" "$file" 2>/dev/null || cat "$file"
    else
        # awk fallback: pass through only known elements and text
        awk -v known="${known[*]}" '
        BEGIN {
            n = split(known, ka, " ");
            for (i in ka) allowed[ka[i]] = 1;
        }
        {
            line = $0;
            # Pass through if not a tag line
            if (line !~ /<[^>]+>/) { print line; next }
            # Extract tag name (strip leading /, attributes, etc.)
            tag = line;
            gsub(/.*<\//, "", tag); gsub(/>.*/, "", tag);
            if (tag in allowed) { print line; next }
            tag = line;
            gsub(/.*</, "", tag); gsub(/[ \/>].*/, "", tag);
            if (tag in allowed) { print line; next }
            # Keep XML declaration and root element
            if (line ~ /^<\?xml/ || line ~ /<specfarm/ || line ~ /<\/specfarm/) {
                print line;
            }
        }' "$file"
    fi
}

# xml_validate FILE
# Basic well-formedness check. Returns 0 if valid, 1 if not.
# Example: xml_validate rules.xml && echo "Valid XML"
xml_validate() {
    local file="$1"
    if _xml_has_xmlstarlet; then
        xmlstarlet val "$file" >/dev/null 2>&1
    else
        # Minimal check: opening and closing tags should balance (rough heuristic)
        local opens closes
        opens=$(grep -c '<[^/!?][^>]*>' "$file" 2>/dev/null || echo 0)
        closes=$(grep -c '</[^>]*>' "$file" 2>/dev/null || echo 0)
        [[ "$opens" -eq "$closes" ]]
    fi
}
