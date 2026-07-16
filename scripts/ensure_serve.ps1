# Start local serve.ps1 only if port is free (safe for logon / scheduled task)
param([int]$Port = 8080)

$ErrorActionPreference = "Stop"
$ServeScript = Join-Path $PSScriptRoot "serve.ps1"
$RepoRoot = Split-Path $PSScriptRoot -Parent

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

if (Test-PortOpen $Port) {
    exit 0
}

Start-Process powershell.exe -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-WindowStyle", "Minimized",
    "-File", "`"$ServeScript`"", "-Port", "$Port"
) -WorkingDirectory $RepoRoot | Out-Null
