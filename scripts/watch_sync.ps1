# Watch CURSOR — simple polling watcher (reliable on Windows)
param(
    [int]$IntervalSeconds = 60
)

$ErrorActionPreference = "Stop"
$CursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$AutoSyncScript = Join-Path $PSScriptRoot "auto_sync.ps1"
$DailyFolder = [string][char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043D + [char]0x0435 + [char]0x0432 + [char]0x043D + [char]0x0438 + [char]0x043A
$CalendarName = [string][char]0x041A + [char]0x0410 + [char]0x041B + [char]0x0415 + [char]0x041D + [char]0x0414 + [char]0x0410 + [char]0x0420 + [char]0x042C + '.md'

function Get-WatchHash() {
    $files = Get-ChildItem -Path $CursorRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $DailyFolder -and ($_.Name -eq 'BACKLOG.md' -or $_.Name -eq $CalendarName) }
    $hash = [System.Text.StringBuilder]::new()
    foreach ($f in ($files | Sort-Object FullName)) {
        [void]$hash.AppendLine("$($f.FullName)|$($f.LastWriteTimeUtc.Ticks)")
    }
    return $hash.ToString()
}

Write-Host ""
Write-Host "  Polling: $CursorRoot" -ForegroundColor Cyan
Write-Host "  Every: ${IntervalSeconds}s | Ctrl+C to stop"
Write-Host ""

$last = Get-WatchHash
while ($true) {
    Start-Sleep -Seconds $IntervalSeconds
    $current = Get-WatchHash
    if ($current -ne $last) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Changes found — syncing..." -ForegroundColor Yellow
        & $AutoSyncScript
        $last = $current
    }
}
