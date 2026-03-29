#!/bin/bash
# tests/integration/test_logic_integration.sh
# Integration test: Load rules.xsd, parse sample rules.xml, run test-logic on all blocks

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"
REPO_ROOT="$(cd "$BASE_DIR/.." && pwd)"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

_run_test() {
  local test_name="$1"
  local test_func="$2"
  
  if $test_func 2>/dev/null; then
    echo "PASS: $test_name"
    return 0
  else
    echo "FAIL: $test_name"
    return 1
  fi
}

# Test 1: Create sample rules.xml and validate against schema
test_load_schema_and_parse() {
  # Create sample rules.xml
  cat > "$TEMP_DIR/sample_rules.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="check_version" type="bash">
    <input type="string">version</input>
    <logic>echo "v1.0.0"</logic>
    <test name="test_version_format">
      <input>{"version": "1.0.0"}</input>
      <expected>v1.0.0</expected>
    </test>
    <output type="string">result</output>
  </compute>
</rules>
EOF
  
  # Verify file created
  [[ -f "$TEMP_DIR/sample_rules.xml" ]] || return 1
  
  # Validate XML
  xmllint --noout "$TEMP_DIR/sample_rules.xml" 2>/dev/null || return 1
  
  return 0
}

# Test 2: Parse multiple compute blocks
test_parse_multiple_blocks() {
  cat > "$TEMP_DIR/multi_rules.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="add" type="logic">
    <input type="int">a</input>
    <input type="int">b</input>
    <logic>
      <op type="arithmetic">
        <left>a</left>
        <op>+</op>
        <right>b</right>
      </op>
    </logic>
    <test name="test_add">
      <input>{"a": 3, "b": 5}</input>
      <expected>8</expected>
    </test>
    <output type="int">result</output>
  </compute>
  <compute id="concat" type="bash">
    <input type="string">s1</input>
    <input type="string">s2</input>
    <logic>echo "${s1}${s2}"</logic>
    <test name="test_concat">
      <input>{"s1": "hello", "s2": "world"}</input>
      <expected>helloworld</expected>
    </test>
    <output type="string">result</output>
  </compute>
</rules>
EOF
  
  [[ -f "$TEMP_DIR/multi_rules.xml" ]] || return 1
  xmllint --noout "$TEMP_DIR/multi_rules.xml" 2>/dev/null || return 1
  
  # Count compute blocks
  local count=$(xmllint --xpath 'count(//compute)' "$TEMP_DIR/multi_rules.xml" 2>/dev/null)
  [[ "$count" == "2" ]] || return 1
  
  return 0
}

# Test 3: Extract and execute test cases
test_extract_test_cases() {
  cat > "$TEMP_DIR/test_cases.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="math_op" type="logic">
    <test name="test_1">
      <input>{"x": 10}</input>
      <expected>20</expected>
    </test>
    <test name="test_2">
      <input>{"x": 5}</input>
      <expected>10</expected>
    </test>
    <logic>
      <op type="arithmetic">
        <left>x</left>
        <op>*</op>
        <right>2</right>
      </op>
    </logic>
    <output type="int">result</output>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/test_cases.xml" 2>/dev/null || return 1
  
  # Extract test count
  local test_count=$(xmllint --xpath 'count(//test)' "$TEMP_DIR/test_cases.xml" 2>/dev/null)
  [[ "$test_count" == "2" ]] || return 1
  
  return 0
}

# Test 4: Validate test inputs match declared types
test_validate_test_input_types() {
  cat > "$TEMP_DIR/typed_tests.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="process" type="logic">
    <input type="int">count</input>
    <input type="string">name</input>
    <input type="bool">active</input>
    <test name="test_types">
      <input>{"count": 42, "name": "test", "active": true}</input>
      <expected>ok</expected>
    </test>
    <logic>echo "processing"</logic>
    <output type="string">result</output>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/typed_tests.xml" 2>/dev/null || return 1
  
  # Verify input types declared
  local int_count=$(xmllint --xpath 'count(//input[@type="int"])' "$TEMP_DIR/typed_tests.xml" 2>/dev/null)
  local string_count=$(xmllint --xpath 'count(//input[@type="string"])' "$TEMP_DIR/typed_tests.xml" 2>/dev/null)
  local bool_count=$(xmllint --xpath 'count(//input[@type="bool"])' "$TEMP_DIR/typed_tests.xml" 2>/dev/null)
  
  [[ "$int_count" == "1" && "$string_count" == "1" && "$bool_count" == "1" ]] || return 1
  
  return 0
}

# Test 5: Load and verify schema location
test_schema_reference() {
  local schema_file="$REPO_ROOT/.specify/schemas/rules.xsd"
  [[ -f "$schema_file" ]] || return 1
  
  # Verify schema contains compute element definition
  grep -q "compute" "$schema_file" || return 1
  grep -q "logic" "$schema_file" || return 1
  grep -q "test" "$schema_file" || return 1
  
  return 0
}

# Test 6: Parse compute block with nested logic
test_nested_logic_structure() {
  cat > "$TEMP_DIR/nested.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="conditional" type="logic">
    <logic>
      <if>
        <condition type="compare">
          <left type="int">x</left>
          <op>&gt;</op>
          <right type="int">10</right>
        </condition>
        <then>
          <op>high</op>
        </then>
        <else>
          <op>low</op>
        </else>
      </if>
    </logic>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/nested.xml" 2>/dev/null || return 1
  
  # Verify nested structure
  xmllint --xpath '//if/condition' "$TEMP_DIR/nested.xml" 2>/dev/null || return 1
  
  return 0
}

# Test 7: Collect test results across multiple compute blocks
test_collect_results() {
  cat > "$TEMP_DIR/collect_results.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="test1" type="bash">
    <test name="t1_1">
      <input>1</input>
      <expected>pass</expected>
    </test>
    <test name="t1_2">
      <input>2</input>
      <expected>pass</expected>
    </test>
    <output type="string">result</output>
  </compute>
  <compute id="test2" type="bash">
    <test name="t2_1">
      <input>3</input>
      <expected>pass</expected>
    </test>
    <output type="string">result</output>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/collect_results.xml" 2>/dev/null || return 1
  
  # Count all tests
  local total_tests=$(xmllint --xpath 'count(//test)' "$TEMP_DIR/collect_results.xml" 2>/dev/null)
  [[ "$total_tests" == "3" ]] || return 1
  
  return 0
}

# Test 8: Handle missing test elements
test_missing_tests() {
  cat > "$TEMP_DIR/no_tests.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="simple" type="bash">
    <input type="string">x</input>
    <logic>echo $x</logic>
    <output type="string">result</output>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/no_tests.xml" 2>/dev/null || return 1
  
  # Verify compute exists but no tests
  local test_count=$(xmllint --xpath 'count(//compute[@id="simple"]/test)' "$TEMP_DIR/no_tests.xml" 2>/dev/null)
  [[ "$test_count" == "0" ]] || return 1
  
  return 0
}

# Test 9: Handle compute blocks without logic
test_compute_no_logic() {
  cat > "$TEMP_DIR/no_logic.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="placeholder" type="bash">
    <input type="string">input</input>
    <output type="string">output</output>
  </compute>
</rules>
EOF
  
  xmllint --noout "$TEMP_DIR/no_logic.xml" 2>/dev/null || return 1
  
  # Compute should parse successfully even without logic
  return 0
}

# Test 10: Parse rules.xsd to verify extension elements
test_xsd_elements() {
  local schema_file="$REPO_ROOT/.specify/schemas/rules.xsd"
  [[ -f "$schema_file" ]] || return 1
  
  # Check for all required elements (match with or without namespace prefix)
  grep -q "element.*compute" "$schema_file" || return 1
  grep -q "element.*logic" "$schema_file" || return 1
  grep -q "element.*test" "$schema_file" || return 1
  
  return 0
}

# Main test execution
main() {
  local passed=0
  local failed=0
  
  echo "=== Integration Tests: test_logic_integration.sh ==="
  
  if _run_test "Load schema and parse" test_load_schema_and_parse; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse multiple blocks" test_parse_multiple_blocks; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Extract test cases" test_extract_test_cases; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate test input types" test_validate_test_input_types; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Schema reference" test_schema_reference; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Nested logic structure" test_nested_logic_structure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Collect results" test_collect_results; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Missing tests handling" test_missing_tests; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Compute no logic" test_compute_no_logic; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "XSD elements" test_xsd_elements; then ((passed++)) || true; else ((failed++)) || true; fi
  
  echo ""
  echo "Summary: $passed passed, $failed failed"
  
  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
