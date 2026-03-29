#!/bin/bash
# tests/unit/test_logic_type_validation.sh
# Unit tests for validating test inputs/outputs against declared types

set -euo pipefail

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

# Helper: Validate integer type
validate_int() {
  local value="$1"
  if [[ "$value" =~ ^-?[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

# Helper: Validate string type
validate_string() {
  local value="$1"
  [[ -n "$value" ]] && return 0 || return 1
}

# Helper: Validate boolean type
validate_bool() {
  local value="$1"
  [[ "$value" == "true" || "$value" == "false" ]] && return 0 || return 1
}

# Helper: Validate enum type (predefined values)
validate_enum() {
  local value="$1"
  shift
  local valid_values=("$@")
  
  for valid in "${valid_values[@]}"; do
    [[ "$value" == "$valid" ]] && return 0
  done
  return 1
}

# Test 1: Validate integer input
test_validate_int_input() {
  local input=42
  validate_int "$input" || return 1
  return 0
}

# Test 2: Reject non-integer input
test_reject_non_int_input() {
  local input="abc"
  validate_int "$input" && return 1  # Should fail
  return 0
}

# Test 3: Validate negative integer
test_validate_negative_int() {
  local input=-15
  validate_int "$input" || return 1
  return 0
}

# Test 4: Validate string input
test_validate_string_input() {
  local input="hello"
  validate_string "$input" || return 1
  return 0
}

# Test 5: Reject empty string
test_reject_empty_string() {
  local input=""
  validate_string "$input" && return 1  # Should fail
  return 0
}

# Test 6: Validate string with spaces
test_validate_string_with_spaces() {
  local input="hello world"
  validate_string "$input" || return 1
  return 0
}

# Test 7: Validate boolean true
test_validate_bool_true() {
  local input="true"
  validate_bool "$input" || return 1
  return 0
}

# Test 8: Validate boolean false
test_validate_bool_false() {
  local input="false"
  validate_bool "$input" || return 1
  return 0
}

# Test 9: Reject non-boolean
test_reject_non_bool() {
  local input="yes"
  validate_bool "$input" && return 1  # Should fail
  return 0
}

# Test 10: Validate enum from allowed values
test_validate_enum_valid() {
  local input="linux"
  validate_enum "$input" "linux" "windows" "macos" || return 1
  return 0
}

# Test 11: Reject enum not in allowed values
test_reject_enum_invalid() {
  local input="freebsd"
  validate_enum "$input" "linux" "windows" "macos" && return 1  # Should fail
  return 0
}

# Test 12: Type conversion int to string
test_type_convert_int_to_string() {
  local int_val=42
  local string_val="$int_val"
  validate_string "$string_val" || return 1
  return 0
}

# Test 13: Validate zero integer
test_validate_zero() {
  local input=0
  validate_int "$input" || return 1
  return 0
}

# Test 14: Validate large integer
test_validate_large_int() {
  local input=9999999999
  validate_int "$input" || return 1
  return 0
}

# Test 15: Type mismatch detection - int where string expected
test_type_mismatch_int_to_string_allowed() {
  local input=42
  # Converting int to string is usually safe
  validate_string "$input" || return 1
  return 0
}

# Test 16: Validate string containing only digits (ambiguous)
test_validate_numeric_string() {
  local input="123"
  validate_string "$input" || return 1
  return 0
}

# Test 17: Validate enum with numeric values
test_validate_enum_numeric() {
  local input="1"
  validate_enum "$input" "0" "1" "2" || return 1
  return 0
}

# Test 18: Validate special characters in string
test_validate_string_special_chars() {
  local input="test@#$%^&*()"
  validate_string "$input" || return 1
  return 0
}

# Test 19: Validate unicode in string
test_validate_string_unicode() {
  local input="hello🌍"
  validate_string "$input" || return 1
  return 0
}

# Test 20: Multiple type validation in sequence
test_multiple_type_validation() {
  local int_val=42
  local string_val="test"
  local bool_val="true"
  
  validate_int "$int_val" || return 1
  validate_string "$string_val" || return 1
  validate_bool "$bool_val" || return 1
  
  return 0
}

# Test 21: Type validation with JSON-like input
test_validate_json_types() {
  # Simulate parsing JSON object with types
  local json='{"count":5,"name":"test","active":true}'
  
  # Extract and validate count (integer)
  local count=$(echo "$json" | grep -o '"count":[0-9]*' | cut -d':' -f2)
  validate_int "$count" || return 1
  
  return 0
}

# Test 22: Floating point rejection (bash doesn't natively support floats as int)
test_reject_float_as_int() {
  local input="3.14"
  validate_int "$input" && return 1  # Should fail
  return 0
}

# Test 23: Array type representation
test_array_type_representation() {
  # Arrays in bash are represented as space-separated strings
  local -a arr=("a" "b" "c")
  local arr_str="${arr[*]}"
  validate_string "$arr_str" || return 1
  return 0
}

# Test 24: Nullable type handling
test_nullable_type() {
  # Treat empty string as null for optional fields
  local input=""
  # For nullable fields, empty string is acceptable
  [[ -z "$input" ]] && return 0
  return 1
}

# Test 25: Type validation with leading zeros
test_int_with_leading_zeros() {
  local input="0042"
  validate_int "$input" || return 1
  return 0
}

# Main test execution
main() {
  local passed=0
  local failed=0
  
  echo "=== Unit Tests: test_logic_type_validation.sh ==="
  
  if _run_test "Validate integer input" test_validate_int_input; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject non-integer input" test_reject_non_int_input; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate negative integer" test_validate_negative_int; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate string input" test_validate_string_input; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject empty string" test_reject_empty_string; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate string with spaces" test_validate_string_with_spaces; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate boolean true" test_validate_bool_true; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate boolean false" test_validate_bool_false; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject non-boolean" test_reject_non_bool; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate enum valid" test_validate_enum_valid; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject enum invalid" test_reject_enum_invalid; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Type convert int to string" test_type_convert_int_to_string; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate zero integer" test_validate_zero; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate large integer" test_validate_large_int; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Type mismatch int to string" test_type_mismatch_int_to_string_allowed; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate numeric string" test_validate_numeric_string; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate enum numeric" test_validate_enum_numeric; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate string special chars" test_validate_string_special_chars; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate string unicode" test_validate_string_unicode; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Multiple type validation" test_multiple_type_validation; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Validate JSON types" test_validate_json_types; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Reject float as int" test_reject_float_as_int; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Array type representation" test_array_type_representation; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Nullable type handling" test_nullable_type; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Integer with leading zeros" test_int_with_leading_zeros; then ((passed++)) || true; else ((failed++)) || true; fi
  
  echo ""
  echo "Summary: $passed passed, $failed failed"
  
  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
