# Start local server (if needed) and open Ежедневник in browser
param([int]$Port = 8080)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ServeScript = Join-Path $PSScriptRoot "serve.ps1"
$Url = "http://localhost:$Port/"

function Test-PortOpen([int]$P) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect("127.0.0.1", $P)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-PortOpen $Port)) {
    Write-Host "Starting server on port $Port..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Minimized",
        "-File", "`"$ServeScript`"", "-Port", $Port
    ) -WorkingDirectory $RepoRoot | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        if (Test-PortOpen $Port) { $ready = $true; break }
    }
    if (-not $ready) {
        Write-Error "Server did not start on port $Port"
        exit 1
    }
}

Start-Process $Url
Write-Host "Opened $Url" -ForegroundColor Green
