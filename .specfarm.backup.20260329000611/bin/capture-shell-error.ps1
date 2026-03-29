# bin/capture-shell-error.ps1 - PowerShell-native shell-error capture (Phase 3b T048)
# Mirrors bin/capture-shell-error.sh for Windows/PowerShell environments
# Captures $Error[], sanitizes secrets, logs to shell-errors.log, and triggers nudges
# Usage: .\capture-shell-error.ps1 -Command <cmd> [-Args <args...>]

param(
    [Parameter(Position=0)]
    [string]$Command = "",
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$CommandArgs = @(),
    [switch]$DryRun = $false,
    [switch]$NoNudge = $false
)

$ErrorActionPreference = "Continue"  # Allow $Error[] accumulation

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommandPath
$BASE_DIR = Split-Path -Parent $SCRIPT_DIR

$SpecfarmHome = if ($env:SPECFARM_HOME) { $env:SPECFARM_HOME } else { ".specfarm" }
$ShellErrorsLog = Join-Path $SpecfarmHome "shell-errors.log"
$NudgeConf = Join-Path $BASE_DIR "rules\nudges\windows-antipatterns.conf"
$CI_NudgeConf = Join-Path $BASE_DIR "rules\nudges\ci-antipatterns.conf"

# Ensure directories exist
$null = New-Item -ItemType Directory -Force -Path $SpecfarmHome
if (-not (Test-Path $ShellErrorsLog)) {
    New-Item -ItemType File -Force -Path $ShellErrorsLog | Out-Null
}

function Remove-Secrets {
    param([string]$Text)
    $Text = $Text -replace 'Bearer\s+\S+', 'Bearer REDACTED'
    $Text = $Text -replace '\s+-p\s+\S+', ' -p REDACTED'
    $Text = $Text -replace '--password\s+\S+', '--password REDACTED'
    $Text = $Text -replace '--token\s+\S+', '--token REDACTED'
    $Text = $Text -replace 'arn:aws:[^\s]+', 'arn:aws:REDACTED'
    $Text = $Text -replace 'api[-_]?key=\S+', 'api-key=REDACTED'
    $Text = $Text -replace 'apikey=\S+', 'apikey=REDACTED'
    $Text = $Text -replace 'secret=\S+', 'secret=REDACTED'
    $Text = $Text -replace 'password=\S+', 'password=REDACTED'
    $Text = $Text -replace 'https://[^:]+:[^@]+@', 'https://REDACTED:REDACTED@'
    return $Text
}

function Write-ErrorLog {
    param([string]$Json)
    $sw = [System.IO.StreamWriter]::new($ShellErrorsLog, $true, [System.Text.Encoding]::UTF8)
    try { $sw.Write($Json + "`n") } finally { $sw.Close() }
}

function Get-ISOTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Read antipattern patterns from conf file
function Get-NudgePatterns {
    param([string]$ConfPath)
    if (-not (Test-Path $ConfPath)) { return @() }
    Get-Content $ConfPath | Where-Object {
        $_ -notmatch '^\s*#' -and $_ -match '\S'
    }
}

# Check if error matches known antipatterns (T049: wire $Error[] into drift engine)
function Test-Antipattern {
    param([string]$ErrorMessage, [string[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($ErrorMessage -match $pattern) {
            return $pattern
        }
    }
    return $null
}

function Invoke-WithCapture {
    param([string]$Cmd, [string[]]$Args)
    if (-not $Cmd) {
        Write-Error "Usage: capture-shell-error.ps1 <command> [args...]"
        exit 1
    }

    # Clear $Error before running
    $Error.Clear()

    # Execute the command
    $exitCode = 0
    $stdout = ""
    $stderr = ""
    try {
        $result = & $Cmd @Args 2>&1
        $stdout = ($result | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
        $stderr = ($result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join "`n"
        $exitCode = $LASTEXITCODE
    } catch {
        $stderr = $_.Exception.Message
        $exitCode = 1
    }

    if ($exitCode -ne 0 -or $Error.Count -gt 0) {
        $sanitizedCmd = Remove-Secrets "$Cmd $($Args -join ' ')"
        $sanitizedStderr = Remove-Secrets $stderr

        # Load antipattern patterns
        $winPatterns = Get-NudgePatterns $NudgeConf
        $ciPatterns = Get-NudgePatterns $CI_NudgeConf
        $allPatterns = $winPatterns + $ciPatterns

        # Check for antipattern matches in $Error[] (T049 wiring)
        $matchedRules = @()
        foreach ($errRecord in $Error) {
            $errMsg = $errRecord.Exception.Message
            $hit = Test-Antipattern -ErrorMessage $errMsg -Patterns $allPatterns
            if ($hit) { $matchedRules += $hit }
        }
        if ($sanitizedStderr) {
            $hit = Test-Antipattern -ErrorMessage $sanitizedStderr -Patterns $allPatterns
            if ($hit) { $matchedRules += $hit }
        }

        # Build log entry
        $entry = [ordered]@{
            timestamp    = Get-ISOTimestamp
            command      = $sanitizedCmd
            exit_code    = $exitCode
            stderr       = $sanitizedStderr
            ps_errors    = ($Error | ForEach-Object { Remove-Secrets $_.Exception.Message })
            matched_rules = ($matchedRules | Select-Object -Unique)
            ps_version   = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
        } | ConvertTo-Json -Compress

        if ($DryRun) {
            Write-Host "[DRY RUN] Would log: $entry"
        } else {
            Write-ErrorLog $entry
            if ($env:SPECFARM_VERBOSE -eq "1") {
                Write-Warning "Shell error captured: exit=$exitCode cmd=$sanitizedCmd"
            }
        }

        # Emit nudge if antipatterns found
        if (-not $NoNudge -and $matchedRules.Count -gt 0) {
            Write-Warning "⚠ SpecFarm nudge: error matches Windows antipattern(s): $($matchedRules -join ', ')"
        }
    }

    Write-Output $stdout
    exit $exitCode
}

Invoke-WithCapture -Cmd $Command -Args $CommandArgs
