#!/bin/bash
# Integration test for scoped drift in SpecFarm Phase 2

set -euo pipefail

# Setup temporary test environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r . "$TEST_DIR"
cd "$TEST_DIR"

# Initialize .specfarm/config
mkdir -p .specfarm
cat <<EOF > .specfarm/config
VIBE="plain"
PHASE_MODE="loose"
DRIFT_THRESHOLD=5
EOF

# Create a sample rules.xml with scoped rules
cat <<EOF > .specfarm/rules.xml
<specfarm version="1.0">
  <rule id="GLOBAL-01" global="true">
    <description>Global rule</description>
    <signature type="keyword">global_marker</signature>
    <certainty>1.0</certainty>
  </rule>
  <rule id="PAYROLL-01" folder="payroll">
    <description>Payroll rule</description>
    <signature type="keyword">payroll_marker</signature>
    <certainty>1.0</certainty>
  </rule>
  <rule id="SCHEDULING-01" folder="scheduling">
    <description>Scheduling rule</description>
    <signature type="keyword">scheduling_marker</signature>
    <certainty>1.0</certainty>
  </rule>
</specfarm>
EOF

# Create sample files
mkdir -p payroll scheduling common
echo "global_marker" > common/base.txt
echo "payroll_marker" > payroll/pay.txt
echo "scheduling_marker" > scheduling/sched.txt

chmod +x .specfarm/bin/specfarm .specfarm/bin/drift-engine

echo "Running global drift check..."
./.specfarm/bin/specfarm drift > global_drift.log
grep -q "GLOBAL-01" global_drift.log
grep -q "PAYROLL-01" global_drift.log
grep -q "SCHEDULING-01" global_drift.log

echo "Running scoped drift check (payroll)..."
./.specfarm/bin/specfarm drift payroll > payroll_drift.log
grep -q "GLOBAL-01" payroll_drift.log
grep -q "PAYROLL-01" payroll_drift.log
if grep -q "SCHEDULING-01" payroll_drift.log; then
    echo "Error: SCHEDULING-01 found in payroll-scoped drift"
    exit 1
fi

echo "Scoped drift test PASSED"
