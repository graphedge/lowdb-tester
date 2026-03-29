# bin/justifications-log.ps1 - PowerShell-native justifications log management (Phase 3b T032)
# Mirrors bin/justifications-log.sh for Windows/PowerShell environments
# Supports: log, has, list, purge sub-commands
# Format: JSON Lines with timestamp, rule, rationale, commit SHA

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    [Parameter(Position=1)]
    [string]$Arg1 = "",
    [Parameter(Position=2)]
    [string]$Arg2 = "",
    [Parameter(Position=3)]
    [string]$Arg3 = "",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

$SpecfarmHome = if ($env:SPECFARM_HOME) { $env:SPECFARM_HOME } else { ".specfarm" }
$JustificationsLog = Join-Path $SpecfarmHome "justifications.log"

# Ensure directory and file exist
$null = New-Item -ItemType Directory -Force -Path $SpecfarmHome
if (-not (Test-Path $JustificationsLog)) {
    New-Item -ItemType File -Force -Path $JustificationsLog | Out-Null
}

function Get-CommitSha {
    try { (git rev-parse HEAD 2>$null).Trim() } catch { "unknown" }
}

function Get-ISOTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Read log with CRLF normalization — all entries returned as LF-only strings
function Read-JustificationsLog {
    if (-not (Test-Path $JustificationsLog)) { return @() }
    Get-Content -Path $JustificationsLog -Encoding UTF8 | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ -ne "" }
}

# Write a single JSON line to log using LF line endings
function Write-JustificationEntry {
    param([string]$Json)
    # Normalize to LF by appending via StreamWriter
    $sw = [System.IO.StreamWriter]::new($JustificationsLog, $true, [System.Text.Encoding]::UTF8)
    try {
        $sw.Write($Json + "`n")
    } finally {
        $sw.Close()
    }
}

function Invoke-Log {
    param(
        [string]$Rule = "unknown",
        [string]$Rationale = "no rationale provided",
        [string]$Context = ""
    )
    if (-not $Rule) {
        Write-Error "Usage: justifications-log.ps1 log <rule> <rationale> [context]"
        exit 1
    }
    $entry = [ordered]@{
        timestamp = Get-ISOTimestamp
        rule      = $Rule
        rationale = $Rationale
        commit    = Get-CommitSha
        context   = $Context
    } | ConvertTo-Json -Compress

    # Validate JSON (round-trip)
    $null = $entry | ConvertFrom-Json
    Write-JustificationEntry $entry
    Write-Host "✓ Logged: rule='$Rule' at $(Get-Date -Format 'HH:mm:ss')"
}

function Invoke-Has {
    param([string]$Rule)
    if (-not $Rule) {
        Write-Error "Usage: justifications-log.ps1 has <rule>"
        exit 1
    }
    $entries = Read-JustificationsLog
    $found = $entries | Where-Object { ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue).rule -eq $Rule }
    if ($found) {
        Write-Host "✓ Rule '$Rule' found in justifications log"
        exit 0
    } else {
        Write-Host "✗ Rule '$Rule' not found in justifications log"
        exit 1
    }
}

function Invoke-List {
    param([string]$Format = "brief")
    $entries = Read-JustificationsLog
    if (-not $entries) {
        Write-Host "No justifications recorded."
        return
    }
    $parsed = $entries | ForEach-Object {
        $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
    } | Where-Object { $_ }

    switch ($Format) {
        "brief" {
            Write-Host "=== Justifications Log (Brief) ==="
            $parsed | Format-Table -Property timestamp, rule, rationale -AutoSize
        }
        "full" {
            Write-Host "=== Justifications Log (Full) ==="
            $parsed | ConvertTo-Json -Depth 5
        }
        default {
            Write-Error "Unknown format: $Format (use: brief, full)"
            exit 1
        }
    }
}

function Invoke-Purge {
    if (-not $Force) {
        $response = Read-Host "WARNING: This will clear the justifications log. Continue? (yes/no)"
        if ($response -ne "yes") { Write-Host "Cancelled."; return }
    }
    "" | Set-Content -Path $JustificationsLog -NoNewline -Encoding UTF8
    Write-Host "✓ Justifications log cleared."
}

function Show-Help {
    Write-Host @"
Usage: justifications-log.ps1 <command> [options]

Commands:
  log <rule> <rationale> [context]  - Log a justification entry
  has <rule>                         - Check if rule exists in log
  list [brief|full]                  - Display all justifications (default: brief)
  purge [-Force]                     - Clear the log (prompts unless -Force)
  help                               - Show this help message

Examples:
  .\justifications-log.ps1 log "rule-name" "Rationale for exception"
  .\justifications-log.ps1 has "rule-name"
  .\justifications-log.ps1 list brief
  .\justifications-log.ps1 purge -Force

Environment:
  SPECFARM_HOME  - Directory for .specfarm (default: current dir)
"@
}

# Dispatch
switch ($Command.ToLower()) {
    "log"   { Invoke-Log -Rule $Arg1 -Rationale $Arg2 -Context $Arg3 }
    "has"   { Invoke-Has -Rule $Arg1 }
    "list"  { Invoke-List -Format (if ($Arg1) { $Arg1 } else { "brief" }) }
    "purge" { Invoke-Purge }
    default { Show-Help }
}
