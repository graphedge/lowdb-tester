#!/bin/bash
# repo-mix-fallback.sh — zero-dependency pseudocode filter for briefing generation
# Simulates RepoMix filtering by excluding noisy patterns (*.xml, *.stub, TODOs, etc.)

set -euo pipefail

# Read filter patterns from .specfarm/filters.md if present, else use defaults
FILTER_FILE=".specfarm/filters.md"
EXCLUDE_PATTERNS=(
  '\.xml$'
  'pseudocode/'
  '\.stub$'
  '^// TODO'
  '^<!-- TODO'
)

# If .specfarm/filters.md exists, extract custom patterns
if [[ -f "$FILTER_FILE" ]]; then
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    # Lines starting with ! denote exclusions
    if [[ "$line" == "!"* ]]; then
      pattern="${line:1}"
      EXCLUDE_PATTERNS+=("$pattern")
    fi
  done < "$FILTER_FILE"
fi

# Build grep exclusion flags
GREP_OPTS=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  GREP_OPTS+="-E '$pattern|' "
done
GREP_OPTS=${GREP_OPTS%\| }  # Remove trailing |

# List files via git, then filter
git ls-files | grep -v $GREP_OPTS 2>/dev/null || true
