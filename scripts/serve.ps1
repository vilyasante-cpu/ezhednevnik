# Local static server for Ежедневник web UI (no Node/Python required)
param([int]$Port = 8080)

$WebRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "web"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host ""
Write-Host "  Ежедневник: http://localhost:$Port" -ForegroundColor Green
Write-Host "  Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".ico"  = "image/x-icon"
}

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.LocalPath
        if ($path -eq "/") { $path = "/index.html" }
        $file = Join-Path $WebRoot ($path.TrimStart('/').Replace('/', '\'))

        if (Test-Path $file -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $ctx.Response.ContentType = $mime[$ext]
            if (-not $ctx.Response.ContentType) { $ctx.Response.ContentType = "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $ctx.Response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $ctx.Response.Close()
    }
} finally {
    $listener.Stop()
}
