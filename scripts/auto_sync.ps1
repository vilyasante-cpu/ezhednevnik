# Auto-sync: scan CURSOR markdown -> planner.json -> git push -> GitHub Pages
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

# 1. Rebuild JSON from markdown sources
Log "Sync data..." "Cyan"
& (Join-Path $PSScriptRoot "sync_data.ps1") | Out-Null

# 2. Check for changes
Set-Location $RepoRoot
$status = & $Git status --porcelain data/planner.json web/data/planner.json 2>&1
if (-not $status) {
    Log "No changes — skip push" "DarkGray"
    exit 0
}

# 3. Commit
$ts = Get-Date -Format "dd.MM.yyyy HH:mm"
$commitMsg = if ($Message) { $Message } else { "sync: planner.json $ts" }
& $Git add data/planner.json web/data/planner.json
& $Git -c user.name="Ezhednevnik Sync" -c user.email="pc@users.noreply.github.com" commit -m $commitMsg
Log "Committed: $commitMsg" "Green"

# 4. Push
& $Git push origin main
Log "Pushed to GitHub" "Green"
Log "Pages will redeploy automatically (1-2 min)" "DarkGray"
