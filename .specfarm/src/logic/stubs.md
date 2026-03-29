# Test Stub Templates for Common Logic Patterns

Collection of reusable test stubs for `<compute>` blocks in rules.xml.

## Overview

These templates provide inline XML test stubs for common logic patterns used in drift detection and remediation. Each template includes:
- Input specifications with types
- Logic definition
- Test cases with inputs and expected outputs

## Arithmetic Patterns

### Addition

```xml
<compute id="add_numbers" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="arithmetic">
      <left>a</left>
      <op>+</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_add_positive">
    <input>{"a": 5, "b": 3}</input>
    <expected>8</expected>
  </test>
  <test name="test_add_negative">
    <input>{"a": -2, "b": 3}</input>
    <expected>1</expected>
  </test>
  <output type="int">result</output>
</compute>
```

### Subtraction

```xml
<compute id="subtract_numbers" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="arithmetic">
      <left>a</left>
      <op>-</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_subtract">
    <input>{"a": 10, "b": 3}</input>
    <expected>7</expected>
  </test>
  <output type="int">result</output>
</compute>
```

### Multiplication

```xml
<compute id="multiply_numbers" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="arithmetic">
      <left>a</left>
      <op>*</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_multiply">
    <input>{"a": 6, "b": 7}</input>
    <expected>42</expected>
  </test>
  <output type="int">result</output>
</compute>
```

### Division

```xml
<compute id="divide_numbers" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="arithmetic">
      <left>a</left>
      <op>/</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_divide">
    <input>{"a": 20, "b": 4}</input>
    <expected>5</expected>
  </test>
  <output type="int">result</output>
</compute>
```

### Modulo

```xml
<compute id="modulo_numbers" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="arithmetic">
      <left>a</left>
      <op>%</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_modulo">
    <input>{"a": 17, "b": 5}</input>
    <expected>2</expected>
  </test>
  <output type="int">result</output>
</compute>
```

## String Manipulation Patterns

### Concatenation

```xml
<compute id="concat_strings" type="bash">
  <input type="string">s1</input>
  <input type="string">s2</input>
  <logic>echo "${s1}${s2}"</logic>
  <test name="test_concat">
    <input>{"s1": "hello", "s2": "world"}</input>
    <expected>helloworld</expected>
  </test>
  <output type="string">result</output>
</compute>
```

### Substring Extraction

```xml
<compute id="extract_substring" type="bash">
  <input type="string">str</input>
  <input type="int">start</input>
  <input type="int">length</input>
  <logic>echo "${str:$start:$length}"</logic>
  <test name="test_substring">
    <input>{"str": "foobar", "start": 0, "length": 3}</input>
    <expected>foo</expected>
  </test>
  <output type="string">result</output>
</compute>
```

### String Length

```xml
<compute id="string_length" type="bash">
  <input type="string">str</input>
  <logic>echo "${#str}"</logic>
  <test name="test_length">
    <input>{"str": "testing"}</input>
    <expected>7</expected>
  </test>
  <output type="int">result</output>
</compute>
```

### String Replacement

```xml
<compute id="replace_string" type="bash">
  <input type="string">str</input>
  <input type="string">old</input>
  <input type="string">new</input>
  <logic>echo "${str//$old/$new}"</logic>
  <test name="test_replace">
    <input>{"str": "hello world", "old": "world", "new": "there"}</input>
    <expected>hello there</expected>
  </test>
  <output type="string">result</output>
</compute>
```

### Uppercase Conversion

```xml
<compute id="to_uppercase" type="bash">
  <input type="string">str</input>
  <logic>echo "${str^^}"</logic>
  <test name="test_upper">
    <input>{"str": "hello"}</input>
    <expected>HELLO</expected>
  </test>
  <output type="string">result</output>
</compute>
```

## Conditional Patterns

### Equality Check

```xml
<compute id="check_equal" type="logic">
  <input type="string">a</input>
  <input type="string">b</input>
  <logic>
    <op type="compare">
      <left>a</left>
      <op>==</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_equal_true">
    <input>{"a": "test", "b": "test"}</input>
    <expected>true</expected>
  </test>
  <test name="test_equal_false">
    <input>{"a": "test", "b": "other"}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

### Greater Than

```xml
<compute id="check_greater" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="compare">
      <left>a</left>
      <op>&gt;</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_greater_true">
    <input>{"a": 10, "b": 5}</input>
    <expected>true</expected>
  </test>
  <test name="test_greater_false">
    <input>{"a": 3, "b": 5}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

### Less Than or Equal

```xml
<compute id="check_lte" type="logic">
  <input type="int">a</input>
  <input type="int">b</input>
  <logic>
    <op type="compare">
      <left>a</left>
      <op>&lt;=</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_lte_equal">
    <input>{"a": 5, "b": 5}</input>
    <expected>true</expected>
  </test>
  <test name="test_lte_less">
    <input>{"a": 3, "b": 5}</input>
    <expected>true</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

## Regex Patterns

### Pattern Matching

```xml
<compute id="match_pattern" type="bash">
  <input type="string">text</input>
  <input type="string">pattern</input>
  <logic>
    if [[ "$text" =~ $pattern ]]; then
      echo "true"
    else
      echo "false"
    fi
  </logic>
  <test name="test_match_true">
    <input>{"text": "file_2026-03-19.log", "pattern": ".*\\.log$"}</input>
    <expected>true</expected>
  </test>
  <test name="test_match_false">
    <input>{"text": "file.txt", "pattern": ".*\\.log$"}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

### Extract Capture Groups

```xml
<compute id="extract_capture" type="bash">
  <input type="string">text</input>
  <input type="string">pattern</input>
  <logic>
    if [[ "$text" =~ $pattern ]]; then
      echo "${BASH_REMATCH[1]}"
    else
      echo "no_match"
    fi
  </logic>
  <test name="test_extract">
    <input>{"text": "version=1.2.3", "pattern": "version=([0-9.]+)"}</input>
    <expected>1.2.3</expected>
  </test>
  <output type="string">result</output>
</compute>
```

### Contains Check

```xml
<compute id="contains_substring" type="bash">
  <input type="string">haystack</input>
  <input type="string">needle</input>
  <logic>
    if [[ "$haystack" =~ $needle ]]; then
      echo "true"
    else
      echo "false"
    fi
  </logic>
  <test name="test_contains_true">
    <input>{"haystack": "hello world", "needle": "world"}</input>
    <expected>true</expected>
  </test>
  <test name="test_contains_false">
    <input>{"haystack": "hello world", "needle": "goodbye"}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

## Logical Operations

### AND Operation

```xml
<compute id="logical_and" type="logic">
  <input type="bool">a</input>
  <input type="bool">b</input>
  <logic>
    <op type="logical">
      <left>a</left>
      <op>AND</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_and_both_true">
    <input>{"a": true, "b": true}</input>
    <expected>true</expected>
  </test>
  <test name="test_and_one_false">
    <input>{"a": true, "b": false}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

### OR Operation

```xml
<compute id="logical_or" type="logic">
  <input type="bool">a</input>
  <input type="bool">b</input>
  <logic>
    <op type="logical">
      <left>a</left>
      <op>OR</op>
      <right>b</right>
    </op>
  </logic>
  <test name="test_or_both_false">
    <input>{"a": false, "b": false}</input>
    <expected>false</expected>
  </test>
  <test name="test_or_one_true">
    <input>{"a": true, "b": false}</input>
    <expected>true</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

### NOT Operation

```xml
<compute id="logical_not" type="logic">
  <input type="bool">a</input>
  <logic>
    <op type="logical">
      <op>NOT</op>
      <right>a</right>
    </op>
  </logic>
  <test name="test_not_true">
    <input>{"a": true}</input>
    <expected>false</expected>
  </test>
  <test name="test_not_false">
    <input>{"a": false}</input>
    <expected>true</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

## Enum Validation

### Enum Match

```xml
<compute id="validate_enum" type="bash">
  <input type="string">value</input>
  <input type="enum">allowed_values</input>
  <logic>
    case "$value" in
      linux|windows|macos) echo "true" ;;
      *) echo "false" ;;
    esac
  </logic>
  <test name="test_enum_valid">
    <input>{"value": "linux", "allowed_values": ["linux", "windows", "macos"]}</input>
    <expected>true</expected>
  </test>
  <test name="test_enum_invalid">
    <input>{"value": "freebsd", "allowed_values": ["linux", "windows", "macos"]}</input>
    <expected>false</expected>
  </test>
  <output type="bool">result</output>
</compute>
```

## Conditional Branching

### If-Then-Else

```xml
<compute id="conditional_branch" type="logic">
  <input type="int">x</input>
  <logic>
    <if>
      <condition type="compare">
        <left>x</left>
        <op>&gt;</op>
        <right>10</right>
      </condition>
      <then>
        <op>high</op>
      </then>
      <else>
        <op>low</op>
      </else>
    </if>
  </logic>
  <test name="test_if_true">
    <input>{"x": 15}</input>
    <expected>high</expected>
  </test>
  <test name="test_if_false">
    <input>{"x": 5}</input>
    <expected>low</expected>
  </test>
  <output type="string">result</output>
</compute>
```

## Usage

1. **Copy the template** that matches your logic pattern
2. **Customize inputs and logic** for your use case
3. **Update test cases** with realistic inputs and expected outputs
4. **Add to `rules.xml`** within the appropriate `<rule>` block
5. **Run tests**: `specfarm test-logic --path . --output results.json`

## Testing Your Templates

After adding templates to rules.xml:

```bash
# Run full test suite
specfarm test-logic --path . --output artifacts/test-results.json --verbose

# Run unit tests
bash tests/unit/test_logic_stubs.sh

# Run integration tests
bash tests/integration/test_logic_integration.sh
```

## Best Practices

- **Keep logic simple**: Complex nested operations are harder to test
- **Use descriptive test names**: e.g., `test_boundary_case` instead of `test_1`
- **Test edge cases**: Zero, negative numbers, empty strings, special characters
- **Type validation**: Ensure inputs match declared types
- **Error handling**: Account for invalid inputs and boundary conditions
- **Documentation**: Add comments explaining the logic pattern

## See Also

- [Data Model: Compute Blocks](../specs/004-specfarm-phase-4/data-model.md)
- [Drift Engine Reference](../src/drift/drift_engine.sh)
- [Rules Schema](../.specify/schemas/rules.xsd)
