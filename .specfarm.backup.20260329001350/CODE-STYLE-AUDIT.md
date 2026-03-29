# Code Style Audit (T035)

**Date**: 2026-03-28
**Scope**: `.specfarm/bin/` and `.specfarm/src/`

## Summary

Audited all shell scripts for consistency in:
- Shebangs (`#!/usr/bin/env bash` or `#!/bin/bash`)
- Error handling (`set -euo pipefail` or `set -e`)
- Quoting styles

## Findings

### Shebangs: ✓ PASS
All `.sh` files have proper shebangs.

### Error Handling: ⚠️ ADVISORY
**26 files** missing `set -e` or `set -euo pipefail`:

Files deliberately avoiding `set -e` (sourced libraries):
- `src/drift/drift_engine.sh` - Sourced by drift-engine
- `src/vibe/nudge_engine.sh` - Sourced by drift-engine
- `src/drift/export_markdown.sh` - Sourced by drift-engine
- `src/openspec/xml_bridge.sh` - Sourced by drift-engine
- `src/crossplatform/*.sh` - Sourced by various scripts

Files that may benefit from `set -e`:
- `bin/auto-generate-rules.sh`
- `bin/justifications-log.sh`
- `bin/xml-helpers.sh`
- `bin/spec-env-brief.sh`

**Recommendation**: Add `set -euo pipefail` to **entry point scripts** only (bin/).
Do NOT add to **sourced libraries** (src/) to avoid breaking callers that handle errors.

### New Files (Phase 3): ✓ COMPLIANT
All new files created in T026-T033 follow best practices:
- ✓ `bin/specfarm-stub` - Has `set -euo pipefail`
- ✓ `src/crosscheck/run_checks.sh` - Has `set -euo pipefail`
- ✓ `tests/unit/test_stub_templates.sh` - Has `set -euo pipefail`
- ✓ `tests/integration/test_stub_generation.sh` - Has `set -euo pipefail`
- ✓ `tests/integration/test_crosscheck_runner.sh` - Has `set -euo pipefail`
- ✓ `tests/e2e/test_stub_crosscheck_workflow.sh` - Has `set -euo pipefail`

### Quoting Styles: ⚠️ MIXED
Mixed quoting detected (single vs double quotes for strings).
Not a blocking issue; bash accepts both.

## Actions Taken

1. Verified all new Phase 3 files have proper error handling
2. Documented findings for future refactoring
3. No breaking changes applied to existing files

## Recommendations for Future Work

1. Add `set -euo pipefail` to entry point scripts in `bin/`
2. Add shellcheck pragma comments to sourced libraries:
   ```bash
   # shellcheck disable=SC2317  # Don't require set -e in sourced files
   ```
3. Standardize on double quotes for string literals (optional)
4. Run shellcheck on all files and address warnings (non-blocking)

## Constitutional Compliance

✓ All new files follow Constitutional Principle I (CLI-Centric)
✓ All new files follow Constitutional Principle II.A (Zero-Dependency Testing)
✓ No violations introduced by T026-T035 changes
