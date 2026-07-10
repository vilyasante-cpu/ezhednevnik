# Local server for Ежедневник web UI + write-back API for closing events
param([int]$Port = 8080)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$WebRoot = Join-Path $RepoRoot "web"
$CloseScript = Join-Path $PSScriptRoot "close_event.ps1"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host ""
Write-Host "  Ежедневник: http://localhost:$Port" -ForegroundColor Green
Write-Host "  API: POST /api/close-event" -ForegroundColor DarkGray
Write-Host "  Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".ico"  = "image/x-icon"
}

function Send-Bytes([System.Net.HttpListenerContext]$Ctx, [byte[]]$Bytes, [int]$Code, [string]$Type) {
    $Ctx.Response.StatusCode = $Code
    $Ctx.Response.ContentType = $Type
    $Ctx.Response.ContentLength64 = $Bytes.Length
    $Ctx.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Ctx.Response.Close()
}

function Read-JsonBody([System.Net.HttpListenerRequest]$Req) {
    $reader = New-Object System.IO.StreamReader($Req.InputStream, $Req.ContentEncoding)
    $text = $reader.ReadToEnd()
    if (-not $text) { return @{} }
    return ($text | ConvertFrom-Json)
}

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.LocalPath
        $method = $ctx.Request.HttpMethod

        if ($path -eq "/api/health" -and $method -eq "GET") {
            $body = '{"ok":true,"writable":true}' 
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            Send-Bytes $ctx $bytes 200 "application/json; charset=utf-8"
            continue
        }

        if ($path -eq "/api/close-event" -and $method -eq "POST") {
            try {
                $payload = Read-JsonBody $ctx.Request
                $key = [string]$payload.key
                $outcome = [string]$payload.outcome
                if (-not $key) {
                    $err = '{"ok":false,"error":"key required"}'
                    Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($err)) 400 "application/json; charset=utf-8"
                    continue
                }
                $result = & $CloseScript -Key $key -Outcome $outcome 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $msg = ($result | Out-String).Trim()
                    $errJson = (@{ ok = $false; error = $msg } | ConvertTo-Json -Compress)
                    Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($errJson)) 404 "application/json; charset=utf-8"
                    continue
                }
                $okJson = [string]$result
                if ($okJson -notmatch '^\{') { $okJson = (@{ ok = $true } | ConvertTo-Json -Compress) }
                Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($okJson)) 200 "application/json; charset=utf-8"
            } catch {
                $errJson = (@{ ok = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress)
                Send-Bytes $ctx ([System.Text.Encoding]::UTF8.GetBytes($errJson)) 500 "application/json; charset=utf-8"
            }
            continue
        }

        if ($path -eq "/") { $path = "/index.html" }
        $file = Join-Path $WebRoot ($path.TrimStart('/').Replace('/', '\'))

        if (Test-Path $file -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $type = $mime[$ext]
            if (-not $type) { $type = "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            Send-Bytes $ctx $bytes 200 $type
        } else {
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            Send-Bytes $ctx $msg 404 "text/plain; charset=utf-8"
        }
    }
} finally {
    $listener.Stop()
}
