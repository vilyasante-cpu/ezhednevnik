# Register Windows scheduled task for auto-sync (every 30 minutes)
param(
    [int]$IntervalMinutes = 30,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$TaskName = "Ezhednevnik-AutoSync"
$ScriptPath = Join-Path $PSScriptRoot "auto_sync.ps1"
$RepoRoot = Split-Path $PSScriptRoot -Parent

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed task: $TaskName" -ForegroundColor Yellow
    exit 0
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Quiet"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Auto-sync Ezhednevnik planner.json to GitHub every $IntervalMinutes min" `
    -Force | Out-Null

Write-Host ""
Write-Host "  Task registered: $TaskName" -ForegroundColor Green
Write-Host "  Interval: every $IntervalMinutes minutes"
Write-Host "  Script: $ScriptPath"
Write-Host ""
Write-Host "  Run now:  powershell -File scripts/auto_sync.ps1"
Write-Host "  Remove:   powershell -File scripts/install_autosync_task.ps1 -Uninstall"
Write-Host ""
