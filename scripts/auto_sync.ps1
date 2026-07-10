# Auto-sync: scan CURSOR markdown -> planner.json -> mirror docs -> git push
param(
    [switch]$Quiet,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Git = "C:\Program Files\Git\bin\git.exe"

function Log([string]$Text, [string]$Color = "Gray") {
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Color }
}

Log "Sync data..." "Cyan"
& (Join-Path $PSScriptRoot "sync_data.ps1") | Out-Null

Set-Location $RepoRoot

# Block accidental commit of local full data
$tracked = & $Git ls-files --others --exclude-standard 2>&1
$localLeak = & $Git diff --cached --name-only 2>&1 | Where-Object { $_ -match 'planner\.local\.json' }
if ($localLeak) {
    & $Git reset HEAD -- $localLeak 2>&1 | Out-Null
    Write-Error "Blocked: planner.local.json must not be committed"
    exit 1
}

$status = & $Git status --porcelain data/planner.json web/data/planner.json docs/ 2>&1
if (-not $status) {
    Log "No changes - skip push" "DarkGray"
    exit 0
}

$ts = Get-Date -Format "dd.MM.yyyy HH:mm"
$commitMsg = if ($Message) { $Message } else { "sync: planner.json $ts" }
& $Git add data/planner.json web/data/planner.json docs/
& $Git -c user.name="Ezhednevnik Sync" -c user.email="pc@users.noreply.github.com" commit -m $commitMsg
Log "Committed: $commitMsg" "Green"

& $Git push origin main
Log "Pushed to GitHub - Pages redeploys from main/docs" "Green"
