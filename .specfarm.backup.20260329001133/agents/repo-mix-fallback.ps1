# repo-mix-fallback.ps1 — zero-dependency pseudocode filter for briefing generation (PowerShell)
# Simulates RepoMix filtering by excluding noisy patterns (*.xml, *.stub, TODOs, etc.)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Default filter patterns
$excludePatterns = @(
  '\.xml$'
  'pseudocode/'
  '\.stub$'
  '^// TODO'
  '^<!-- TODO'
)

# If .specfarm/filters.md exists, extract custom patterns
$filterFile = '.specfarm/filters.md'
if (Test-Path $filterFile) {
  $content = Get-Content $filterFile -Raw
  foreach ($line in $content -split "`n") {
    $line = $line.Trim()
    # Skip comments and empty lines
    if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    # Lines starting with ! denote exclusions
    if ($line.StartsWith('!')) {
      $pattern = $line.Substring(1)
      $excludePatterns += $pattern
    }
  }
}

# List files via git and filter
try {
  $files = & git ls-files
  foreach ($file in $files) {
    $excluded = $false
    foreach ($pattern in $excludePatterns) {
      if ($file -match $pattern) {
        $excluded = $true
        break
      }
    }
    if (-not $excluded) {
      Write-Output $file
    }
  }
}
catch {
  # Silently fail if git not available (matching bash behavior)
}
