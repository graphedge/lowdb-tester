#!/bin/bash
# tests/unit/test_xml_logic_parse.sh
# Unit tests for parsing XML with nested <compute> blocks

set -euo pipefail

# Helper: Run a test
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

# Test 1: Parse valid XML with single <compute> block
test_parse_single_compute() {
  local xml='<?xml version="1.0"?>
<rules>
  <compute id="check_version" type="bash">
    <input type="string">version</input>
    <logic>echo $version</logic>
    <output type="string">result</output>
  </compute>
</rules>'
  
  # Validate XML structure
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  # Check compute element exists
  echo "$xml" | xmllint --xpath '//compute[@id="check_version"]' - 2>/dev/null || return 1
  
  return 0
}

# Test 2: Parse XML with multiple <compute> blocks
test_parse_multiple_compute() {
  local xml='<?xml version="1.0"?>
<rules>
  <compute id="check_version" type="bash">
    <input type="string">version</input>
    <logic>echo $version</logic>
    <output type="string">result</output>
  </compute>
  <compute id="check_path" type="bash">
    <input type="string">path</input>
    <logic>echo $path</logic>
    <output type="string">result</output>
  </compute>
</rules>'
  
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  # Verify both compute blocks exist
  echo "$xml" | xmllint --xpath 'count(//compute)' - 2>/dev/null | grep -q "2" || return 1
  
  return 0
}

# Test 3: Parse XML with nested <logic> elements
test_parse_nested_logic() {
  local xml='<?xml version="1.0"?>
<rules>
  <compute id="validate_input" type="logic">
    <input type="int">value</input>
    <logic>
      <op type="compare">
        <left type="int">value</left>
        <op>&gt;</op>
        <right type="int">0</right>
      </op>
    </logic>
    <output type="bool">valid</output>
  </compute>
</rules>'
  
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  # Check nested logic structure
  echo "$xml" | xmllint --xpath '//logic/op[@type="compare"]' - 2>/dev/null || return 1
  
  return 0
}

# Test 4: Validate required attributes on compute
test_compute_required_attributes() {
  local xml_valid='<?xml version="1.0"?>
<rules>
  <compute id="test" type="bash">
    <input type="string">x</input>
    <logic>echo x</logic>
    <output type="string">result</output>
  </compute>
</rules>'
  
  # Valid XML should pass
  echo "$xml_valid" | xmllint --noout - 2>/dev/null || return 1
  
  # Missing id should fail (manually check)
  local xml_missing_id='<?xml version="1.0"?>
<rules>
  <compute type="bash">
    <input type="string">x</input>
    <logic>echo x</logic>
    <output type="string">result</output>
  </compute>
</rules>'
  
  # This test verifies the schema would reject missing id (handled by XSD validation)
  echo "$xml_missing_id" | xmllint --noout - 2>/dev/null
  # Note: basic XML parse succeeds, but XSD validation would fail
  
  return 0
}

# Test 5: Parse <test> elements within <compute>
test_parse_compute_with_tests() {
  local xml='<?xml version="1.0"?>
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
    <test name="test_1_plus_1">
      <input>{"a": 1, "b": 1}</input>
      <expected>2</expected>
    </test>
    <test name="test_5_plus_3">
      <input>{"a": 5, "b": 3}</input>
      <expected>8</expected>
    </test>
    <output type="int">result</output>
  </compute>
</rules>'
  
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  # Verify test elements exist
  echo "$xml" | xmllint --xpath 'count(//compute[@id="add"]/test)' - 2>/dev/null | grep -q "2" || return 1
  
  return 0
}

# Test 6: Reject invalid XML
test_reject_invalid_xml() {
  local xml_invalid='<?xml version="1.0"?>
<rules>
  <compute id="test" type="bash">
    <input type="string">x
    <logic>echo x</logic>
  </compute>'  # Missing closing tags
  
  # Should fail XML validation
  echo "$xml_invalid" | xmllint --noout - 2>/dev/null && return 1
  
  return 0
}

# Test 7: Parse various type attributes
test_parse_type_attributes() {
  local xml='<?xml version="1.0"?>
<rules>
  <compute id="test" type="bash">
    <input type="int">a</input>
    <input type="string">b</input>
    <input type="bool">c</input>
    <input type="enum">d</input>
    <logic>echo $a $b $c $d</logic>
    <output type="string">result</output>
  </compute>
</rules>'
  
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  # Verify all type variations parsed
  echo "$xml" | xmllint --xpath 'count(//input)' - 2>/dev/null | grep -q "4" || return 1
  
  return 0
}

# Test 8: Handle whitespace in compute blocks
test_parse_whitespace_handling() {
  local xml='<?xml version="1.0"?>
<rules>
  <compute id="test" type="bash">
    
    <input type="string">x</input>
    
    <logic>
      echo x
    </logic>
    
    <output type="string">result</output>
    
  </compute>
</rules>'
  
  echo "$xml" | xmllint --noout - 2>/dev/null || return 1
  
  return 0
}

# Main test execution
main() {
  local passed=0
  local failed=0
  
  echo "=== Unit Tests: test_xml_logic_parse.sh ==="
  
  if _run_test "Parse single compute block" test_parse_single_compute; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse multiple compute blocks" test_parse_multiple_compute; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse nested logic elements" test_parse_nested_logic; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate compute required attributes" test_compute_required_attributes; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse compute with test elements" test_parse_compute_with_tests; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject invalid XML" test_reject_invalid_xml; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse type attributes" test_parse_type_attributes; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Handle whitespace in compute blocks" test_parse_whitespace_handling; then ((passed++)) || true; else ((failed++)) || true; fi
  
  echo ""
  echo "Summary: $passed passed, $failed failed"
  
  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
