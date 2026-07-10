$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$local = Get-Content (Join-Path $Root "data\planner.local.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$pub = Get-Content (Join-Path $Root "data\planner.json") -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "=== STATS ==="
Write-Host "LOCAL:" ($local.stats | ConvertTo-Json -Compress)
Write-Host "PUB:  " ($pub.stats | ConvertTo-Json -Compress)

$le = ($local.calendars | ForEach-Object { @($_.events).Count } | Measure-Object -Sum).Sum
$ld = ($local.calendars | ForEach-Object { @($_.deadlines).Count } | Measure-Object -Sum).Sum
$pe = ($pub.calendars | ForEach-Object { @($_.events).Count } | Measure-Object -Sum).Sum
$pd = ($pub.calendars | ForEach-Object { @($_.deadlines).Count } | Measure-Object -Sum).Sum
Write-Host "Events: local=$le pub=$pe | Deadlines: local=$ld pub=$pd"

$lt = ($local.clients | ForEach-Object { @($_.tasks).Count } | Measure-Object -Sum).Sum
$pt = ($pub.clients | ForEach-Object { @($_.tasks).Count } | Measure-Object -Sum).Sum
Write-Host "Tasks sum: local=$lt pub=$pt"

$diff = Compare-Object ($local.clients.name | Sort-Object) ($pub.clients.name | Sort-Object)
if ($diff) { Write-Host "Client name diff:" ($diff | ConvertTo-Json -Compress) }

foreach ($c in $local.clients) {
    $p = $pub.clients | Where-Object { $_.name -eq $c.name } | Select-Object -First 1
    if (-not $p) { Write-Host "MISSING in pub: $($c.name)"; continue }
    if (@($c.tasks).Count -ne @($p.tasks).Count) {
        Write-Host "TASK COUNT $($c.name): local=$(@($c.tasks).Count) pub=$(@($p.tasks).Count)"
    }
    if ($c.project_status -ne $p.project_status) {
        Write-Host "STATUS $($c.name): local=$($c.project_status) pub=$($p.project_status)"
    }
}

Write-Host "LOCAL domains:" ($local.domains -join ',')
Write-Host "PUB domains: " ($pub.domains -join ',')
Write-Host "LOCAL calendars:" $local.calendars.Count
Write-Host "PUB calendars: " $pub.calendars.Count
