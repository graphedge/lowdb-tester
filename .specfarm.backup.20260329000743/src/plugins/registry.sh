#!/bin/bash
# src/plugins/registry.sh — Plugin Registry: manifest loading and activation tracking
# Task T0446: Manages the SpecFarm plugin registry backed by .specfarm/plugins/registry.json
#
# Usage: source this file, then call registry functions
#   register_plugin    <manifest_path>   → adds plugin to registry
#   activate_plugin    <plugin_id>       → marks plugin as active
#   deactivate_plugin  <plugin_id>       → marks plugin as inactive
#   list_plugins                         → lists all registered plugins
#   get_active_plugins                   → lists active plugin ids
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

_registry_file() {
    local root="${SPECFARM_ROOT:-$BASE_DIR}"
    echo "${root}/.specfarm/plugins/registry.json"
}

_init_registry() {
    local reg
    reg="$(_registry_file)"
    local dir
    dir="$(dirname "$reg")"
    mkdir -p "$dir"
    if [[ ! -f "$reg" ]]; then
        echo '{"plugins":[],"active_plugins":[]}' > "$reg"
    fi
}

# Register a plugin from its manifest path
# Writes an entry into registry.json (idempotent by plugin id)
register_plugin() {
    local manifest_path="$1"
    if [[ ! -f "$manifest_path" ]]; then
        echo "ERROR: manifest not found: $manifest_path" >&2
        return 1
    fi

    _init_registry
    local reg
    reg="$(_registry_file)"

    local plugin_id
    plugin_id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$manifest_path" 2>/dev/null)
    if [[ -z "$plugin_id" ]]; then
        echo "ERROR: could not parse plugin id from manifest" >&2
        return 1
    fi

    # Idempotent: skip if already registered
    local already
    already=$(python3 -c "
import json, sys
reg = json.load(open('$reg'))
ids = [p['id'] for p in reg.get('plugins', [])]
print('yes' if '$plugin_id' in ids else 'no')
" 2>/dev/null || echo "no")

    if [[ "$already" == "yes" ]]; then
        echo "SKIP: plugin '$plugin_id' already registered"
        return 0
    fi

    # Add to registry
    python3 - "$reg" "$manifest_path" <<'PYEOF'
import json, sys
reg_path, manifest_path = sys.argv[1], sys.argv[2]
reg = json.load(open(reg_path))
manifest = json.load(open(manifest_path))
entry = {
    "id": manifest["id"],
    "name": manifest["name"],
    "version": manifest["version"],
    "entrypoint": manifest["entrypoint"],
    "manifest_path": manifest_path
}
reg["plugins"].append(entry)
json.dump(reg, open(reg_path, "w"), indent=2)
print("REGISTERED: " + manifest["id"])
PYEOF
}

# Mark a plugin as active in registry.json
activate_plugin() {
    local plugin_id="$1"
    _init_registry
    local reg
    reg="$(_registry_file)"

    python3 - "$reg" "$plugin_id" <<'PYEOF'
import json, sys
reg_path, pid = sys.argv[1], sys.argv[2]
reg = json.load(open(reg_path))
active = reg.get("active_plugins", [])
if pid not in active:
    active.append(pid)
    reg["active_plugins"] = active
    json.dump(reg, open(reg_path, "w"), indent=2)
    print("ACTIVATED: " + pid)
else:
    print("SKIP: already active: " + pid)
PYEOF
}

# Mark a plugin as inactive
deactivate_plugin() {
    local plugin_id="$1"
    _init_registry
    local reg
    reg="$(_registry_file)"

    python3 - "$reg" "$plugin_id" <<'PYEOF'
import json, sys
reg_path, pid = sys.argv[1], sys.argv[2]
reg = json.load(open(reg_path))
active = reg.get("active_plugins", [])
if pid in active:
    active.remove(pid)
    reg["active_plugins"] = active
    json.dump(reg, open(reg_path, "w"), indent=2)
    print("DEACTIVATED: " + pid)
else:
    print("SKIP: not active: " + pid)
PYEOF
}

# List all registered plugins as JSON array
list_plugins() {
    _init_registry
    local reg
    reg="$(_registry_file)"
    python3 -c "
import json
reg = json.load(open('$reg'))
for p in reg.get('plugins', []):
    print(p['id'] + '\t' + p['version'] + '\t' + p['name'])
"
}

# List active plugin ids (one per line)
get_active_plugins() {
    _init_registry
    local reg
    reg="$(_registry_file)"
    python3 -c "
import json
reg = json.load(open('$reg'))
for pid in reg.get('active_plugins', []):
    print(pid)
"
}

# Run when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    case "$cmd" in
        register)   register_plugin "${2:-}" ;;
        activate)   activate_plugin "${2:-}" ;;
        deactivate) deactivate_plugin "${2:-}" ;;
        list)       list_plugins ;;
        active)     get_active_plugins ;;
        *)
            echo "Usage: registry.sh <register|activate|deactivate|list|active> [arg]"
            exit 1
            ;;
    esac
fi
