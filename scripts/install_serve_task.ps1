# Register Windows scheduled task: start local Ежедневник server at logon
param([switch]$Uninstall)

$ErrorActionPreference = "Stop"
$TaskName = "Ezhednevnik-Serve"
$ScriptPath = Join-Path $PSScriptRoot "ensure_serve.ps1"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed task: $TaskName" -ForegroundColor Yellow
    exit 0
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Start Ezhednevnik local server (localhost:8080) at Windows logon" `
    -Force | Out-Null

# Start once now
& $ScriptPath

Write-Host ""
Write-Host "  Task registered: $TaskName" -ForegroundColor Green
Write-Host "  Trigger: at logon ($env:USERNAME)"
Write-Host "  URL: http://localhost:8080"
Write-Host ""
Write-Host "  Remove: powershell -File scripts/install_serve_task.ps1 -Uninstall"
Write-Host ""
