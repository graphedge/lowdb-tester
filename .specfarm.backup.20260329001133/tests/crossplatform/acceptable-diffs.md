# Acceptable Differences — Cross-Platform Parity Testing

**Purpose**: Document expected and acceptable differences between bash (Unix/Linux/macOS) and PowerShell (Windows) outputs. These differences are normalized away in parity validation tests.

**Date**: 2026-03-11  
**Version**: 1.0.0

---

## 1. Line Endings

### Difference
- **Unix/Linux/macOS**: LF (`\n`)
- **Windows PowerShell**: CRLF (`\r\n`)

### How Normalized
Via `src/crossplatform/line-endings.sh`:
```bash
# Convert CRLF → LF for comparison
normalize_line_endings "input.txt"
```

### Test Validation
✅ Both platforms produce identical content when line endings are normalized to LF  
✅ Git configuration respects `core.safecrlf=false` for `.specfarm/` files  
✅ No content loss during round-trip (Read CRLF → Process → Write LF)

### Notes
- Pre-commit hook must use LF line endings on all platforms
- `.gitattributes` should specify `text eol=lf` for `.specfarm/` files
- JSON Lines files (`.specfarm/justifications.log`, `.specfarm/shell-errors.log`) must have consistent line endings

---

## 2. File Paths

### Difference
- **Unix**: `/path/to/file`, `/c/path/from/windows`, `/mnt/c/Users/...` (WSL)
- **Windows**: `C:\path\to\file`, `\\server\share` (UNC)
- **PowerShell in Git Bash**: Can handle both; Git Bash normalizes to Unix

### How Normalized
Via `src/crossplatform/path-normalize.sh`:
```bash
# Convert Windows paths to Unix format
normalize_path "C:\\Users\\test\\file.txt"  # → /c/Users/test/file.txt
normalize_path "\\\\server\\share"           # → //server/share
```

### Test Validation
✅ All paths normalized to Unix forward-slash format  
✅ Drive letters converted: `C:\` → `/c/`  
✅ UNC paths handled: `\\server\share` → `//server/share`  
✅ Relative paths preserved: `..\file` → `../file`  
✅ Spaces in paths handled correctly

### Notes
- Drift table output includes file paths; must normalize for comparison
- Markdown export includes file paths as links; normalization needed before comparison
- Test fixtures use Unix paths; PowerShell adjusts for local execution

---

## 3. ANSI Terminal Colors

### Difference
- **Unix/Linux/macOS with modern terminals**: Full ANSI 256-color support
- **Windows PowerShell 5.1**: No ANSI support (not in standard PS5.1)
- **Windows PowerShell 7+**: ANSI support via `$PSStyle` and `$PSHost`
- **Git Bash on Windows**: ANSI support (MSYS2 compatibility)

### How Normalized
Via `parity-validator.sh`:
```bash
# Strip ANSI escape sequences for comparison
strip_ansi_codes < input.txt > input-stripped.txt
```

### Test Validation
✅ Vibe messaging tone/wording must match (farm/jungle/plain identity consistent)  
✅ ANSI codes stripped; only text content compared  
✅ Color fallback documented: PS5.1 uses plain text, PS7+ uses `$PSStyle`  
✅ Message content identical across platforms (localization differences allow, but discouraged)

### Notes
- `src/vibe/nudge_engine.sh` detects PowerShell version and adjusts output
- Orchestrated parity tests strip ANSI before comparison
- GitHub Actions Windows runner has ANSI support; local testing may differ

---

## 4. Timestamps

### Difference
- **Exact format may vary** between bash (`date +%s`) and PowerShell (`Get-Date -UFormat %s`)
- **Timezone considerations**: Ensure tests run in same timezone or use UTC

### How Normalized
Via `parity-validator.sh`:
```bash
# Replace timestamps with placeholder
sed 's/[0-9]\{10,\}/TIMESTAMP/g' input.txt > input-normalized.txt
```

### Test Validation
✅ Timestamp *presence* validated (log entries have timestamps)  
✅ Timestamp *format* validated separately (Unix epoch, ISO 8601, etc.)  
✅ Timestamp *value* NOT compared (will differ based on execution time)  
✅ No requirement for exact timestamp match across platforms

### Notes
- Justification logs include timestamps; presence important, exact value not
- Shell error logs include timestamps; format checked separately
- Test fixtures use static timestamps for reproducibility

---

## 5. Whitespace (Trailing Spaces, Tabs)

### Difference
- **Trailing whitespace**: May differ based on text editor settings
- **Tab vs spaces**: Bash and PowerShell may handle indentation differently

### How Normalized
Via `parity-validator.sh`:
```bash
# Remove trailing whitespace
sed 's/[[:space:]]*$//' input.txt > input-normalized.txt

# Normalize tabs to spaces
sed 's/\t/    /g' input.txt > input-normalized.txt
```

### Test Validation
✅ Content identical after whitespace normalization  
✅ Tables (drift output) aligned correctly on both platforms  
✅ JSON Lines files have consistent whitespace handling

### Notes
- Drift table output uses aligned columns; comparison after normalization
- JSON parser should ignore whitespace differences
- Markdown export may have different spacing; compare after normalization

---

## 6. PowerShell Version Differences

### Difference
- **PowerShell 5.1** (Windows built-in): Older cmdlets, limited ANSI support, different error output
- **PowerShell 7.x** (Core): Newer features, full ANSI support, different error output
- **Bash on Unix**: No PowerShell version considerations

### How Handled
- **Platform detection**: Detect PowerShell version; adjust expected output accordingly
- **Fallback logic**: PS5.1 uses plain text; PS7+ uses `$PSStyle`
- **Separate test matrix**: CI/CD runs tests on both PS5.1 and PS7.x

### Test Validation
✅ Platform detection script (`src/crossplatform/platform-check.sh`) identifies PS version  
✅ Test fixtures handle both PS5.1 and PS7.x behavior  
✅ GitHub Actions matrix includes both versions  
✅ Error messages may differ; structure must match

### Notes
- `$PSVersionTable.PSVersion.Major` used to detect version
- Graceful degradation for PS5.1 (fewer features, but functional)
- Tests should not assume ANSI support on PS5.1

---

## 7. Environment Variables

### Difference
- **Case sensitivity**: Unix env vars case-sensitive; Windows not case-sensitive in PowerShell
- **Path separator**: `PATH` uses `:` (Unix) vs `;` (Windows) but should be normalized

### How Handled
- **Normalization**: Convert all env var lookups to lowercase
- **Path separator**: Normalize using `path-normalize.sh`

### Test Validation
✅ Environment variables set correctly by each platform  
✅ `DETECTED_OS` and `PS_VERSION` set appropriately  
✅ `SPECFARM_POWERSHELL=1` set when running via PowerShell wrapper

### Notes
- Test fixtures set identical environment for both platforms
- Case-sensitivity differences managed by wrapper scripts
- CI/CD sets `core.safecrlf=false` in git config

---

## 8. Error Messages

### Difference
- **bash**: Error messages from GNU/Linux tools (standard)
- **PowerShell**: Native PowerShell error messages (different format)
- **Git Bash on Windows**: MSYS2 compatibility layer (often similar to Unix)

### How Handled
- **Error structure**: Must match; exact wording may differ
- **Exit codes**: Must match exactly (0 = success, non-zero = failure)
- **Error context**: Both should include rule name, file path, violation type

### Test Validation
✅ Exit codes identical on both platforms  
✅ Error type/category matches (same rule violation detected)  
✅ Exact message text may differ; structure must match  
✅ Error count matches

### Notes
- `src/policy/agent-command-check.sh` handles error formatting
- Pre-commit hook captures and normalizes errors
- Shell error logging must normalize error messages to JSON Lines format

---

## 9. Execution Context Differences

### Difference
- **bash**: Single process, straightforward execution
- **PowerShell**: May have additional process overhead, different error handling
- **Git Bash on Windows**: Adds MSYS2 compatibility layer

### How Handled
- **Process detection**: Platform check scripts identify execution context
- **Exit code handling**: Bash and PowerShell both exit with same codes
- **Output stream handling**: Both stdout/stderr captured and normalized

### Test Validation
✅ Execution context detected correctly  
✅ Output produced regardless of execution context  
✅ Exit codes and stdout/stderr consistent  
✅ No platform-specific side effects

### Notes
- Set `SPECFARM_POWERSHELL=1` when running via .ps1 wrapper for debugging
- Test fixtures should accommodate both execution contexts
- CI/CD runs on dedicated platform; local testing with platform-specific tools

---

## Normalization Process (parity-validator.sh)

The `parity-validator.sh` script applies these normalizations in order:

```bash
1. Strip ANSI color codes
2. Normalize line endings (CRLF → LF)
3. Normalize file paths (Windows → Unix)
4. Replace timestamps with TIMESTAMP placeholder
5. Remove trailing whitespace
6. Normalize tab characters to spaces
7. Sort output (if applicable for unordered results)
```

**Usage**:
```bash
source tests/crossplatform/parity-validator.sh

# Compare two outputs with normalization
normalize_output "bash_output.txt" > bash_normalized.txt
normalize_output "ps_output.txt" > ps_normalized.txt
diff bash_normalized.txt ps_normalized.txt
```

---

## Examples: What's NOT Acceptable (Will Fail Parity Test)

❌ **Different drift scores**: Rule detection inconsistency  
❌ **Missing rules**: One platform generates fewer drift violations  
❌ **Different rule IDs**: Version mismatch or rule definition error  
❌ **Vibe tone mismatch**: farm/jungle/plain messaging differs  
❌ **JSON structure mismatch**: Justification log format differs  
❌ **Exit code difference**: One success, one failure  
❌ **Missing files**: One platform creates `.specfarm/` directories, other doesn't  

---

## Examples: What's Acceptable (Will Pass Parity Test)

✅ **Path format difference**: `C:\path\file` vs `/c/path/file` (normalized)  
✅ **Line ending difference**: CRLF vs LF (normalized)  
✅ **Timestamp difference**: 1234567890 vs 1234567891 (replaced with placeholder)  
✅ **ANSI color difference**: Color codes present vs absent (stripped)  
✅ **Whitespace difference**: Trailing spaces on Windows (normalized)  
✅ **Message capitalization**: Match tone, minor wording OK (pre-approved)  

---

## Review Checklist for New Parity Tests

When adding a new orchestrated parity test:

- [ ] Document which acceptable differences are expected (from list above)
- [ ] Apply normalization via `parity-validator.sh` before comparison
- [ ] Test on both bash and PowerShell locally before commit
- [ ] Run via GitHub Actions `windows-ci.yml` to validate on actual platforms
- [ ] If test fails due to unexpected difference, update this document with new acceptable difference
- [ ] Never suppress a parity failure without documenting why it's acceptable
- [ ] Update PARITY-SPEC.md if new parity requirement discovered

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-11 | 1.0.0 | Initial document; covers 9 acceptable difference categories with normalization procedures |

