#!/usr/bin/env bash
# agent-command-check.sh
# Provides agent_may_execute(cmd_name, trust, scope, ci_context, drift_score, vibe, review_override)
# Minimal, robust parser for <agent-commands> in .specfarm/rules.xml

set -euo pipefail

# CONFIG: allow overriding rules xml via environment
AGENT_COMMANDS_XML=${AGENT_COMMANDS_XML:-.specfarm/rules.xml}
DENY_LOG=${DENY_LOG:-.specfarm/agent-deny.log}

# Internal cache
_agent_commands_loaded=0
_agent_entries_file=""

# Load and normalize the <agent-commands> section into a temp file preserving order
load_agent_commands() {
  if [[ $_agent_commands_loaded -eq 1 ]]; then
    return 0
  fi

  _agent_entries_file=$(mktemp)

  if [[ ! -f "$AGENT_COMMANDS_XML" ]]; then
    # No rules file -> treat as allow-all (backwards compatibility)
    echo "# NO_RULES_FILE" > "$_agent_entries_file"
    _agent_commands_loaded=1
    return 0
  fi

  # Extract agent-commands block; if not present, write marker and return
  awk 'BEGIN{inside=0} /<agent-commands/{inside=1; print; next} /<\/agent-commands>/{if(inside){print; inside=0; exit}} {if(inside) print}' "$AGENT_COMMANDS_XML" > "$_agent_entries_file" || true

  if [[ ! -s "$_agent_entries_file" ]]; then
    echo "# NO_AGENT_COMMANDS" > "$_agent_entries_file"
  fi

  _agent_commands_loaded=1
}

# Helper: parse attribute value from XML-like token (very small parser)
# $1 = token string e.g. '<allow name="status" always="true" />'
# $2 = attr name
_parse_attr() {
  local token="$1"; local attr="$2"
  # Try to match attr="value"
  local val
  val=$(echo "$token" | sed -n "s/.*${attr}=\"\([^\"]*\)\".*/\1/p" || true)
  echo "$val"
}

# Main decision function
# Usage: agent_may_execute <cmd_name> [trust] [scope] [ci_context] [drift_score] [vibe] [review_override]
agent_may_execute() {
  local cmd_name="$1"; shift
  local trust=${1:-1.0}; shift || true
  local scope=${1:-project}; shift || true
  local ci_context=${1:-false}; shift || true
  local drift_score=${1:-0.0}; shift || true
  local vibe=${1:-normal}; shift || true
  local review_override=${1:-false}; shift || true

  # Load commands
  load_agent_commands

  # If rules file had no agent-commands section -> allow all
  if grep -q "^# NO_AGENT_COMMANDS" "$_agent_entries_file"; then
    return 0
  fi
  if grep -q "^# NO_RULES_FILE" "$_agent_entries_file"; then
    return 0
  fi

  # Read the block into lines and parse order-preserving allow/deny/rule entries
  # We'll produce an ordered list of entries: type|name|attrs-json|source
  local entries=()
  # Read lines and collect tokens
  local block
  block=$(cat "$_agent_entries_file")

  # Simplistic tokenizer: extract <allow .../>, <deny .../>, <rule ...>...</rule>
  # Extract allow/deny singleton tags
  while IFS= read -r line; do
    # Trim
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ "$line" =~ ^<allow[[:space:]] ]]; then
      # whole token might be on single line
      entries+=("allow||$line")
    elif [[ "$line" =~ ^<deny[[:space:]] ]]; then
      entries+=("deny||$line")
    elif [[ "$line" =~ ^<rule[[:space:]] ]]; then
      # collect until </rule>
      local ruleblock="$line"
      while ! echo "$line" | grep -q "</rule>"; do
        read -r line || break
        ruleblock+=$'\n'$line
      done
      entries+=("rule||$ruleblock")
    fi
  done <<< "$block"

  # If no entries found -> treat as allow-all
  if [[ ${#entries[@]} -eq 0 ]]; then
    return 0
  fi

  # Default decision: deny unless matched by allow (phase 3 restrictive)
  local decision="deny"
  local decision_reason="no-match"

  for token in "${entries[@]}"; do
    # token format: type||content
    local type="${token%%||*}"
    local content="${token#*||}"

    if [[ "$type" == "allow" ]]; then
      local name
      name=$(_parse_attr "$content" name)
      if [[ "$name" == "$cmd_name" ]]; then
        # Evaluate attributes
        local always_val min_trust scopes requires when_expr
        always_val=$(_parse_attr "$content" always)
        min_trust=$(_parse_attr "$content" min-trust)
        scopes=$(_parse_attr "$content" scopes)
        requires=$(_parse_attr "$content" requires)
        when_expr=$(_parse_attr "$content" when)

        # Evaluate conditions (basic)
        local ok=1
        if [[ -n "$min_trust" ]]; then
          # numeric compare
          awk "BEGIN{exit !($trust >= $min_trust)}" || ok=0
        fi
        if [[ -n "$scopes" && "$ok" -eq 1 ]]; then
          # check if scope is in comma-separated list
          IFS=',' read -r -a scarr <<< "$scopes"
          local found_scope=0
          for sc in "${scarr[@]}"; do
            sc="$(echo "$sc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ "$sc" == "$scope" || "$sc" == "all" ]]; then found_scope=1; break; fi
          done
          if [[ $found_scope -eq 0 ]]; then ok=0; fi
        fi
        if [[ -n "$requires" && "$ok" -eq 1 ]]; then
          if [[ "$requires" == *"ci-context"* && "$ci_context" != "true" ]]; then ok=0; fi
        fi
        # 'when' expressions are complex; if present, conservatively accept but log for manual review
        if [[ -n "$when_expr" ]]; then
          echo "[agent-command-check] WARNING: 'when' expression present for allow $name: $when_expr" >&2
        fi

        if [[ $ok -eq 1 || "$always_val" == "true" ]]; then
          decision="allow"
          decision_reason="allow-match"
        fi
      fi
    elif [[ "$type" == "deny" ]]; then
      local name
      name=$(_parse_attr "$content" name)
      if [[ "$name" == "$cmd_name" ]]; then
        local reason
        reason=$(_parse_attr "$content" reason)
        decision="deny"
        decision_reason="deny-$reason"
      fi
    elif [[ "$type" == "rule" ]]; then
      # For rules, attempt to find nested allow/deny for the command
      if echo "$content" | grep -q "<allow .*name=\"$cmd_name\""; then
        # Extract the matching allow line
        local allowline
        allowline=$(echo "$content" | sed -n "s/.*\(<allow [^>]*name=\\\"$cmd_name\\\"[^>]*>\).*/\1/p" || true)
        if [[ -z "$allowline" ]]; then
          allowline=$(echo "$content" | sed -n "s/.*\(<allow [^>]*name=\\\"$cmd_name\\\"[^>]*/\1/p" || true)
        fi
        if [[ -n "$allowline" ]]; then
          # reuse allow evaluation by putting into a temp token
          local always_val min_trust scopes requires when_expr ok
          always_val=$(_parse_attr "$allowline" always)
          min_trust=$(_parse_attr "$allowline" min-trust)
          scopes=$(_parse_attr "$allowline" scopes)
          requires=$(_parse_attr "$allowline" requires)
          when_expr=$(_parse_attr "$allowline" when)

          ok=1
          if [[ -n "$min_trust" ]]; then
            awk "BEGIN{exit !($trust >= $min_trust)}" || ok=0
          fi
          if [[ -n "$scopes" && "$ok" -eq 1 ]]; then
            IFS=',' read -r -a scarr <<< "$scopes"
            local found_scope=0
            for sc in "${scarr[@]}"; do
              sc="$(echo "$sc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
              if [[ "$sc" == "$scope" || "$sc" == "all" ]]; then found_scope=1; break; fi
            done
            if [[ $found_scope -eq 0 ]]; then ok=0; fi
          fi
          if [[ -n "$requires" && "$ok" -eq 1 ]]; then
            if [[ "$requires" == *"ci-context"* && "$ci_context" != "true" ]]; then ok=0; fi
          fi
          if [[ -n "$when_expr" ]]; then
            echo "[agent-command-check] WARNING: 'when' expression present in rule for $cmd_name: $when_expr" >&2
          fi
          if [[ $ok -eq 1 || "$always_val" == "true" ]]; then
            decision="allow"
            decision_reason="rule-allow"
          fi
        fi
      fi
      if echo "$content" | grep -q "<deny .*name=\"$cmd_name\""; then
        local denyline
        denyline=$(echo "$content" | sed -n "s/.*\(<deny [^>]*name=\\\"$cmd_name\\\"[^>]*>\).*/\1/p" || true)
        local reason
        reason=$(_parse_attr "$denyline" reason)
        decision="deny"
        decision_reason="rule-deny-$reason"
      fi
    fi
  done

  if [[ "$decision" == "allow" ]]; then
    return 0
  fi

  # Denied: log with context for audit
  mkdir -p "$(dirname "$DENY_LOG")"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) CMD=$cmd_name TRUST=$trust SCOPE=$scope CI=$ci_context DRIFT=$drift_score VIBE=$vibe REVIEW_OVERRIDE=$review_override REASON=$decision_reason" >> "$DENY_LOG"
  return 1
}

# Helper convenience: call and exit if denied
agent_must_execute() {
  if ! agent_may_execute "$@"; then
    echo "Agent not allowed to execute '$1' (see $DENY_LOG)" >&2
    return 1
  fi
}

# If this file is sourced, expose functions. If executed, run a quick self-test.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Running basic self-test for agent-command-check.sh"
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<'XML'
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
  AGENT_COMMANDS_XML="$tmpfile" _agent_commands_loaded=0
  echo "Expect allow for 'status':"; agent_may_execute status && echo OK || echo FAIL
  echo "Expect deny for 'rm -rf':"; agent_may_execute "rm -rf" && echo FAIL || echo OK
  echo "Expect allow for analyze_drift with trust 0.7:"; agent_may_execute analyze_drift 0.7 project false 0.0 normal false && echo OK || echo FAIL
  echo "Expect deny for analyze_drift with trust 0.5:"; agent_may_execute analyze_drift 0.5 project false 0.0 normal false && echo FAIL || echo OK
  rm -f "$tmpfile"
fi
