---
description: Test SpecFarm's operational infrastructure and dependencies. Enhanced Post-PR14 with test harness validation, ShellCheck integration, and health monitoring.
model: claude-haiku-4.5
capabilities:
  - environment_check: Verifies presence and version of core dependencies (e.g., xmlstarlet, gawk, Python).
  - config_validation: Checks validity of SpecFarm configuration files (.specfarm/config, rules.xml).
  - path_verification: Ensures required executables are in the system PATH.
  - test_harness_validation: Detects bash arithmetic bugs and exit code mismatches (NEW Post-PR14)
  - shellcheck_integration: Advisory linting for bash scripts (NEW Post-PR14)
  - test_health_monitoring: Tracks pass rates, timeouts, and coverage (NEW Post-PR14)
instructions: |
  The `specfarm.testinfra` agent validates SpecFarm's operational environment and test infrastructure.
  Enhanced Post-PR14 to prevent test harness bugs that caused 0% pass rates.

  **Workflow:**
  1.  **Test Harness Validation:** Detect dangerous bash arithmetic patterns (`&& ((passed++))` under `set -e`)
  2.  **ShellCheck Integration:** Advisory linting (non-blocking, graceful fallback if missing)
  3.  **Test Suite Health:** Run tests with timeout detection, parse results, track pass rates
  4.  **Coverage Analysis:** Check src/tests ratio, identify orphaned source files
  5.  **Dependency Check:** Verify presence of `xmlstarlet`, `gawk`, `Python`, `shellcheck` (optional)
  6.  **Configuration Validation:** Validate `rules.xml`, `.specfarm/config`
  7.  **Report:** Provide clear status with CRITICAL/ADVISORY/HEALTHY verdicts

  **Usage:**
  ```
  /specfarm.testinfra           # Full validation suite
  /specfarm.testinfra --quick   # Skip ShellCheck and coverage analysis
  ```

  **Key Improvements (Post-PR14):**
  - Prevents bash test harness bugs (PR #14 root cause)
  - Enforces exit code paranoia (summary must match exit status)
  - Circuit breaker detection (3× failure patterns)
  - ShellCheck integration (advisory, non-blocking)
---
