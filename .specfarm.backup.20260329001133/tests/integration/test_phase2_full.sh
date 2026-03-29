#!/bin/bash
# Full Integration Test for SpecFarm Phase 2

set -euo pipefail

# Setup temporary test environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r . "$TEST_DIR"
cd "$TEST_DIR"

# Ensure binaries are executable
chmod +x .specfarm/bin/*

echo "--- Testing Onboarding ---"
./.specfarm/bin/specfarm onboard

echo "--- Testing Config Management ---"
./.specfarm/bin/specfarm config set VIBE jungle
[[ "$(./.specfarm/bin/specfarm config get VIBE)" == "jungle" ]] || exit 1
./.specfarm/bin/specfarm config set PHASE_MODE strict
[[ "$(./.specfarm/bin/specfarm config get PHASE_MODE)" == "strict" ]] || exit 1

echo "--- Testing XML Export ---"
./.specfarm/bin/specfarm xml export
[[ -f ".specfarm/rules.xml" ]] || exit 1
grep -q "<phase-constraints mode=\"strict\">" .specfarm/rules.xml

echo "--- Testing Drift Check (Global) ---"
ls -l .specfarm/bin/drift-engine
# At this point, many rules should drift because we haven't implemented signatures in the code
./.specfarm/bin/specfarm drift > global_drift.log
grep -q "TOTAL ADHERENCE:" global_drift.log

echo "--- Testing Justification ---"
# Justify a rule (e.g., from constitution)
# Note: we need to find a rule ID first.
RULE_ID=$(grep -o "CP-[A-Z0-9]\+" .specfarm/rules.xml | head -n 1)
./.specfarm/bin/specfarm justify "$RULE_ID" "Testing justification"
grep -q "$RULE_ID" .specfarm/justifications.log

echo "--- Testing Drift Check (Scoped) ---"
# Create a folder-specific rule manually to test
cat <<EOF > .specfarm/rules.xml
<specfarm version="1.0">
  <rule id="TEST-SCOPE" folder="payroll">
    <description>Test</description>
    <signature>marker</signature>
  </rule>
</specfarm>
EOF
cat .specfarm/rules.xml
mkdir -p payroll
echo "marker" > payroll/file.txt
ls -l payroll/file.txt
./.specfarm/bin/specfarm drift payroll > scoped_drift.log
cat scoped_drift.log
grep -q "PASS" scoped_drift.log

echo "Phase 2 Full Integration Test PASSED"
