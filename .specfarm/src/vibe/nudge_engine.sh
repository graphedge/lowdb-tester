#!/bin/bash
# Nudge Engine for SpecFarm

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/templates.sh"
source "$SCRIPT_DIR/../config_parser.sh"

dispatch_nudge() {
    local adherence=$1
    local vibe=$(get_config "VIBE")
    
    if [[ "$vibe" == "plain" ]]; then
        return
    fi
    
    local message=$(get_nudge "${vibe:-farm}" "$adherence")
    echo -e "
\033[0;33m[VIBE WHISPER]: $message\033[0m"
}
