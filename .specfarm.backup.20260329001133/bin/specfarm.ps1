# SpecFarm CLI - Phase 1 (Seed) - Powershell Version
# Self-dogfooding keywords: CLI_ONLY, TEST_MANDATORY, CONVENTION_CHECK, PRIVILEGE_LEAST, OPTIMIZE_NOW, CI_GATING, DOCUMENTATION, DEPENDENCIES, AMENDMENT_AND_GOVERNANCE

$BASE_DIR = if ($env:BASE_DIR) { $env:BASE_DIR } else { "." }
$SPEC_FARM_DIR = Join-Path $BASE_DIR ".specfarm"
$PHASE_FILE = Join-Path $SPEC_FARM_DIR "phase"
$JUSTIFICATIONS_LOG = Join-Path $SPEC_FARM_DIR "justifications.log"
$CONSTITUTION_FILE = Join-Path $BASE_DIR ".specify/memory/constitution.md"
$RULES_XML = Join-Path $SPEC_FARM_DIR "rules.xml"

if (-not (Test-Path $SPEC_FARM_DIR)) {
    Write-Error "Not a SpecFarm-aware project (no .specfarm directory found)."
    exit 1
}

if (-not (Test-Path $JUSTIFICATIONS_LOG)) {
    New-Item -ItemType File -Path $JUSTIFICATIONS_LOG -Force | Out-Null
}

function Show-Help {
    Write-Host "SpecFarm - The Watchdog of Spec-Driven Development (Powershell)"
    Write-Host "Usage: specfarm.ps1 [subcommand] [arguments]"
    Write-Host ""
    Write-Host "Subcommands:"
    Write-Host "  drift           Show current drift score"
    Write-Host "  justify [id] [reason] Log a justification for drift"
    Write-Host "  phase           Show/set current project phase"
    Write-Host "  xml export      Generate rules.xml from constitution.md"
    Write-Host "  help            Show this help message"
}

function Get-Phase {
    if (Test-Path $PHASE_FILE) {
        return (Get-Content $PHASE_FILE).Trim()
    }
    return "Unknown Phase"
}

function Log-Justification {
    param($RuleId, $Reason)
    $Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    # For simplicity in Phase 1, using 'no-git' if git command fails
    $CommitHash = "no-git"
    try { $CommitHash = (git rev-parse --short HEAD 2>$null) } catch {}
    
    $Line = "$Timestamp | $RuleId | $CommitHash | $Reason"
    Add-Content -Path $JUSTIFICATIONS_LOG -Value $Line
    Write-Host "Justification recorded for '$RuleId'."
}

function Calculate-Drift {
    if (-not (Test-Path $RULES_XML)) {
        Write-Error "rules.xml not found. Run 'specfarm.ps1 xml export' first."
        return
    }

    $Phase = Get-Phase
    Write-Host "SpecFarm Drift Report - $Phase"
    Write-Host ""
    Write-Host ("{0,-25} | {1,-6} | {2}" -f "Rule ID", "Score", "Status")
    Write-Host "--------------------------|--------|---------"

    $TotalScore = 0
    $NumRules = 0
    
    $Rules = Get-Content $RULES_XML | Select-String -Pattern "<rule"
    foreach ($RuleLine in $Rules) {
        $Id = ([regex]::Match($RuleLine, 'id="([^"]+)"').Groups[1].Value)
        $Title = ([regex]::Match($RuleLine, '<description>([^<]+)').Groups[1].Value)
        $NumRules++

        $Keyword = switch ($Id) {
            "architecture" { "CLI_ONLY" }
            "testing" { "TEST_MANDATORY" }
            "code-quality" { "CONVENTION_CHECK" }
            "security" { "PRIVILEGE_LEAST" }
            "performance" { "OPTIMIZE_NOW" }
            default { $Id.ToUpper().Replace("-", "_") }
        }

        $Count = 0
        $SearchDirs = @()
        if (Test-Path (Join-Path $BASE_DIR "bin")) { $SearchDirs += (Join-Path $BASE_DIR "bin") }
        if (Test-Path (Join-Path $BASE_DIR "src")) { $SearchDirs += (Join-Path $BASE_DIR "src") }

        if ($SearchDirs.Count -gt 0) {
            # Search excluding this script itself
            $Files = Get-ChildItem -Path $SearchDirs -Recurse -File | Where-Object { $_.Name -ne "specfarm.ps1" -and $_.Name -ne "specfarm" }
            foreach ($File in $Files) {
                $Count += (Select-String -Path $File.FullName -Pattern $Keyword -Quiet).Count
                if ((Select-String -Path $File.FullName -Pattern $Keyword -Quiet)) {
                    $Count = 1 # We only need presence for score 1.0 in Phase 1
                    break
                }
            }
        }

        $Score = if ($Count -gt 0) { 1.0 } else { 0.0 }
        $Status = "DRIFT"
        
        if (Select-String -Path $JUSTIFICATIONS_LOG -Pattern "\Q$Id\E" -Quiet) {
            $Score = 1.0
            $Status = "JUSTIFIED"
        } elseif ($Score -eq 1.0) {
            $Status = "PASS"
        }

        Write-Host ("{0,-25} | {1,-6:F1} | {2}" -f $Id, $Score, $Status)
        $TotalScore += $Score
    }

    if ($NumRules -gt 0) {
        $Percent = [math]::Floor(($TotalScore / $NumRules) * 100)
        Write-Host "--------------------------|--------|---------"
        Write-Host "TOTAL ADHERENCE: $Percent%"
        
        if ($Percent -lt 80) {
            Write-Host ""
            Write-Host "[FARMER WHISPER]: Crops look a bit weedy ($Percent%). Check your drift or justify your seeds." -ForegroundColor Yellow
        }
    }
}

function Export-Xml {
    if (-not (Test-Path $CONSTITUTION_FILE)) {
        Write-Error "Constitution file not found at $CONSTITUTION_FILE"
        return
    }

    Write-Host "Generating rules.xml from constitution.md..."
    $Header = '<specfarm-rules version="1.0">'
    Set-Content -Path $RULES_XML -Value $Header

    $Lines = Get-Content $CONSTITUTION_FILE | Select-String -Pattern "^### [IVXLCDM]+\."
    foreach ($Line in $Lines) {
        # Extract ID: Architecture, Description: CLI-Centric
        if ($Line -match '### [IVXLCDM]+\. ([^:]+): (.*)') {
            $Id = $Matches[1].ToLower().Replace(" ", "-")
            $Title = $Matches[2]
            $XmlLine = "  <rule id=""$Id"" immutable=""false"" available-from=""Phase 1"" enforced-from=""Phase 1""><description>$Title</description></rule>"
            Add-Content -Path $RULES_XML -Value $XmlLine
        }
    }

    Add-Content -Path $RULES_XML -Value "</specfarm-rules>"
    $RuleCount = (Get-Content $RULES_XML | Select-String -Pattern "<rule").Count
    Write-Host "rules.xml updated. $RuleCount rules detected."
}

# Subcommand routing
$Subcommand = $args[0]
switch ($Subcommand) {
    "drift" { Calculate-Drift }
    "justify" {
        if ($args.Count -lt 3) { Write-Error "justify requires a rule-id and a reason."; exit 1 }
        Log-Justification -RuleId $args[1] -Reason $args[2]
    }
    "phase" {
        if ($args.Count -eq 1) { Get-Phase }
        else { 
            Set-Content -Path $PHASE_FILE -Value $args[1]
            Write-Host "Project phase updated to: $($args[1])"
        }
    }
    "xml" {
        if ($args[1] -eq "export") { Export-Xml }
        else { Write-Error "Usage: specfarm.ps1 xml export"; exit 1 }
    }
    "help" { Show-Help }
    default {
        if ($Subcommand) { Write-Host "Unknown subcommand: $Subcommand" }
        Show-Help
    }
}
