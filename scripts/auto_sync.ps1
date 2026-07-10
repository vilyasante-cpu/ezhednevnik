# Auto-sync: scan CURSOR markdown -> planner.json -> mirror docs -> git push
param(
    [switch]$Quiet,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Git = "C:\Program Files\Git\bin\git.exe"

. (Join-Path $PSScriptRoot "sync_report.ps1")

function Log([string]$Text, [string]$Color = "Gray") {
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Color }
}

if (-not $Quiet) {
    Log "Sync data..." "Cyan"
}
& (Join-Path $PSScriptRoot "sync_data.ps1")

Set-Location $RepoRoot

# Block accidental commit of local full data
$localLeak = & $Git diff --cached --name-only 2>&1 | Where-Object { $_ -match 'planner\.local\.json' }
if ($localLeak) {
    & $Git reset HEAD -- $localLeak 2>&1 | Out-Null
    Write-Error "Blocked: planner.local.json must not be committed"
    exit 1
}

$status = & $Git status --porcelain data/planner.json web/data/planner.json docs/ 2>&1
if (-not $status) {
    if (-not $Quiet) {
        Write-GitSyncReportHost -Committed $false -Pushed $false -Skipped $true -ChangedFiles @()
    }
    exit 0
}

$changedFiles = @($status | ForEach-Object { ($_ -split '\s+', 2)[-1].Trim() })

$ts = Get-Date -Format "dd.MM.yyyy HH:mm"
$commitMsg = if ($Message) { $Message } else { "sync: planner.json $ts" }
& $Git add data/planner.json web/data/planner.json docs/
& $Git -c user.name="Ezhednevnik Sync" -c user.email="pc@users.noreply.github.com" commit -m $commitMsg

$commitHash = (& $Git rev-parse --short HEAD 2>&1).Trim()
Log "Committed: $commitMsg" "Green"

& $Git push origin main
Log "Pushed to GitHub - Pages redeploys from main/docs" "Green"

if (-not $Quiet) {
    Write-GitSyncReportHost -Committed $true -CommitMsg $commitMsg -CommitHash $commitHash -Pushed $true -ChangedFiles $changedFiles -Skipped $false
}
