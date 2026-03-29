#!/usr/bin/env bash
# Simple unit tests for agent-command-check.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/src/policy/agent-command-check.sh"

# Create temporary rules file
tmp=$(mktemp)
cat > "$tmp" <<'XML'
<rules>
  <agent-commands>
    <allow name="status" always="true" />
    <allow name="analyze_drift" min-trust="0.65" scopes="project,repo" />
    <deny name="rm -rf" reason="catastrophic risk" />
    <rule id="high-risk-write">
      <when scope="critical/" />
      <allow name="preview_change" />
      <deny name="auto_apply" reason="requires human review" />
    </rule>
  </agent-commands>
</rules>
XML

AGENT_COMMANDS_XML="$tmp" _agent_commands_loaded=0

echo "Test: status should be allowed"
if agent_may_execute status; then echo PASS; else echo FAIL; exit 1; fi

echo "Test: rm -rf should be denied"
if agent_may_execute "rm -rf"; then echo FAIL; exit 1; else echo PASS; fi

echo "Test: analyze_drift with trust 0.7 should be allowed"
if agent_may_execute analyze_drift 0.7 project false 0.0 normal false; then echo PASS; else echo FAIL; exit 1; fi

echo "Test: analyze_drift with trust 0.5 should be denied"
if agent_may_execute analyze_drift 0.5 project false 0.0 normal false; then echo FAIL; exit 1; else echo PASS; fi

rm -f "$tmp"

echo "All tests passed"
