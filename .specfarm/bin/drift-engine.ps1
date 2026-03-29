# SpecFarm Drift Engine (PowerShell) — Phase 3b
# Windows/PowerShell wrapper that delegates to bash core or uses native PowerShell logic
# Supports: default drift check, --openspec-mode, --export formats, --nudge-quiet, --dry-run

param(
    [string]$DriftScope = "",
    [switch]$OpenSpecMode = $false,
    [string]$ExportFormat = "",
    [switch]$NudgeQuiet = $false,
    [switch]$DryRun = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# Find script directory
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommandPath
$BASE_DIR = Split-Path -Parent $SCRIPT_DIR

# Configuration
$OPENSPEC_MODE = if ($OpenSpecMode) { 1 } else { 0 }
$NUDGE_QUIET = if ($NudgeQuiet) { 1 } else { 0 }
$DRY_RUN = if ($DryRun) { 1 } else { 0 }

# PowerShell version detection
$PS_VERSION = $PSVersionTable.PSVersion.Major
$PS_FULL_VERSION = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

# Helper: Show usage
function Show-Help {
    Write-Host @"
Usage: .\drift-engine.ps1 [OPTIONS] [SCOPE]

Options:
  -OpenSpecMode          Activate OpenSpec compatibility mode (graceful XML ignore)
  -ExportFormat <fmt>    Export drift report to format (default: markdown)
  -NudgeQuiet            Emit nudges as warnings only (never block)
  -DryRun                Print output to stdout; suppress file writes
  -Help                  Show this help message

Scopes:
  (empty)                Scan all rules (global + local)
  <folder>               Filter rules by folder scope

Examples:
  .\drift-engine.ps1                           # Run standard drift check
  .\drift-engine.ps1 -OpenSpecMode             # Enable OpenSpec compatibility
  .\drift-engine.ps1 -ExportFormat markdown    # Export to markdown format
  .\drift-engine.ps1 -NudgeQuiet -DryRun       # Quiet nudges, print to stdout
  .\drift-engine.ps1 payroll -ExportFormat markdown # Export payroll scope to markdown

Environment:
  `$env:OPENSPEC_MODE=1  Enable OpenSpec mode (CLI flag preferred)
  `$env:NUDGE_QUIET=1    Set quiet nudge mode
  `$env:DRY_RUN=1        Enable dry-run mode
"@
}

# Helper: Detect bash availability (Git Bash or WSL bash)
function Test-BashAvailable {
    try {
        $bash_test = & bash -c "echo 'bash available'"
        if ($bash_test -like "*bash available*") {
            return $true
        }
    }
    catch {
        # bash not available
    }
    return $false
}

# Helper: Platform information
function Get-PlatformInfo {
    $os = [System.Environment]::OSVersion
    $info = @{
        OS = "Windows"
        OSVersion = $os.VersionString
        Architecture = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
        PowerShellVersion = $PS_FULL_VERSION
        BashAvailable = Test-BashAvailable
    }
    return $info
}

# Helper: Check if running in Git Bash context
function Test-GitBashContext {
    # Check if bash.exe is in PATH and env:BASH_VERSION is set
    if ($env:BASH_VERSION -or (Get-Command bash -ErrorAction SilentlyContinue)) {
        return $true
    }
    return $false
}

# Helper: Convert Windows path to Unix-style for bash
function Convert-PathForBash {
    param([string]$Path)
    
    if ($Path -match "^[a-zA-Z]:") {
        # Convert C:\path\file to /c/path/file
        $drive = $Path[0].ToLower()
        $rest = $Path.Substring(2) -replace "\\", "/"
        return "/$drive$rest"
    }
    
    return $Path -replace "\\", "/"
}

# Helper: Invoke bash drift-engine with environment
function Invoke-BashDriftEngine {
    param(
        [string]$DriftScope,
        [int]$OpenSpecMode,
        [string]$ExportFormat,
        [int]$NudgeQuiet,
        [int]$DryRun
    )
    
    $bash_args = @()
    if ($OpenSpecMode) { $bash_args += "--openspec-mode" }
    if ($ExportFormat) { $bash_args += "--export"; $bash_args += $ExportFormat }
    if ($NudgeQuiet) { $bash_args += "--nudge-quiet" }
    if ($DryRun) { $bash_args += "--dry-run" }
    if ($DriftScope) { $bash_args += $DriftScope }
    
    # Set environment for bash
    $env:OPENSPEC_MODE = $OpenSpecMode
    $env:NUDGE_QUIET = $NudgeQuiet
    $env:DRY_RUN = $DryRun
    
    # Call bash drift-engine
    $bash_script = Join-Path $SCRIPT_DIR "drift-engine"
    & bash $bash_script @bash_args
}

# Helper: Native PowerShell drift check (stub for future implementation)
function Invoke-NativePowerShellDrift {
    param(
        [string]$DriftScope,
        [int]$OpenSpecMode,
        [int]$NudgeQuiet,
        [int]$DryRun
    )
    
    Write-Warning "Native PowerShell drift engine not yet fully implemented. Falling back to bash."
    Write-Host ""
    
    # Stub: Eventually this will implement drift detection in pure PowerShell
    # For Phase 3b MVP, delegate to bash (T040: pass ExportFormat through)
    Invoke-BashDriftEngine -DriftScope $DriftScope -OpenSpecMode $OpenSpecMode -ExportFormat $ExportFormat -NudgeQuiet $NudgeQuiet -DryRun $DryRun
}

# Helper: Export drift report to markdown (T040: native PS export for no-bash environments)
function Invoke-ExportMarkdown {
    param(
        [string]$Scope = "",
        [switch]$DryRun = $false
    )

    $rulesFile = ".specfarm\rules.xml"
    if (-not (Test-Path $rulesFile)) {
        Write-Error "Rules file not found: $rulesFile"
        exit 1
    }

    $outputDir = if ($env:SPECFARM_OUTPUT_DIR) { $env:SPECFARM_OUTPUT_DIR } else { "reports" }
    $outputFile = if ($env:SPECFARM_OUTPUT_FILE) { $env:SPECFARM_OUTPUT_FILE } else { Join-Path $outputDir "drift.md" }

    # Normalize Windows paths
    $outputFile = $outputFile -replace '\\', '/'

    [xml]$rules = Get-Content $rulesFile -Encoding UTF8
    $ruleList = $rules.SelectNodes("//rule")

    $tableRows = @()
    foreach ($rule in $ruleList) {
        $id = $rule.GetAttribute("id")
        $severity = $rule.GetAttribute("severity")
        $enabled = $rule.GetAttribute("enabled")
        $vibe = $rule.GetAttribute("vibe")
        if ($Scope -and $rule.GetAttribute("scope") -notmatch $Scope) { continue }
        $tableRows += "| $id | $severity | $enabled | $vibe |"
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $tableContent = $tableRows -join "`n"
    $markdown = @"
# SpecFarm Drift Report

**Generated:** $timestamp  
**Scope:** $(if ($Scope) { $Scope } else { "all" })

## Rules Status

| Rule ID | Severity | Enabled | Vibe |
|---------|----------|---------|------|
$tableContent
"@

    if ($DryRun) {
        Write-Output $markdown
    } else {
        $null = New-Item -ItemType Directory -Force -Path $outputDir
        $sw = [System.IO.StreamWriter]::new($outputFile, $false, [System.Text.Encoding]::UTF8)
        try { $sw.Write($markdown) } finally { $sw.Close() }
        Write-Host "✓ Drift report exported to: $outputFile"
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

# Get platform info for logging
$platform_info = Get-PlatformInfo
Write-Debug "Platform: $($platform_info.OS) v$($platform_info.OSVersion) | PowerShell $($platform_info.PowerShellVersion) | Bash: $($platform_info.BashAvailable)"

# Decision: Use bash if available (maintains feature parity with Unix)
# Otherwise use native PowerShell (future enhancement)
if ($ExportFormat -and -not $platform_info.BashAvailable) {
    # T040: Use native PS export when bash unavailable
    if ($ExportFormat -eq "markdown") {
        Invoke-ExportMarkdown -Scope $DriftScope -DryRun:($DRY_RUN -eq 1)
    } else {
        Write-Error "Unsupported export format without bash: $ExportFormat (only 'markdown' supported natively)"
        exit 1
    }
} elseif ($platform_info.BashAvailable) {
    Write-Debug "Using bash drift-engine (cross-platform parity)"
    Invoke-BashDriftEngine -DriftScope $DriftScope -OpenSpecMode $OPENSPEC_MODE -ExportFormat $ExportFormat -NudgeQuiet $NUDGE_QUIET -DryRun $DRY_RUN
}
else {
    Write-Debug "Bash not available, attempting native PowerShell drift engine"
    Invoke-NativePowerShellDrift -DriftScope $DriftScope -OpenSpecMode $OPENSPEC_MODE -NudgeQuiet $NUDGE_QUIET -DryRun $DRY_RUN
}
