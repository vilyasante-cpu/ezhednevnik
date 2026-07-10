# Pin Ежедневник to Windows Start menu (and Desktop)
param([switch]$Uninstall)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$LaunchScript = Join-Path $PSScriptRoot "launch.ps1"
$ShortcutName = [string][char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043d + [char]0x0435 + [char]0x0432 + [char]0x043d + [char]0x0438 + [char]0x043a + '.lnk'

$paths = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$ShortcutName"),
    (Join-Path $env:USERPROFILE "Desktop\$ShortcutName")
)

if ($Uninstall) {
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item $p -Force }
    }
    Write-Host "Removed shortcuts" -ForegroundColor Yellow
    exit 0
}

$shell = New-Object -ComObject WScript.Shell

foreach ($p in $paths) {
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $sc = $shell.CreateShortcut($p)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$LaunchScript`""
    $sc.WorkingDirectory = $RepoRoot
    $sc.Description = "http://localhost:8080"
    $sc.Save()
}

Write-Host ""
Write-Host "  Shortcuts created:" -ForegroundColor Green
foreach ($p in $paths) { Write-Host "    $p" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "  Start menu -> Ezhednevnik (or pin to taskbar)" -ForegroundColor Cyan
Write-Host ""
