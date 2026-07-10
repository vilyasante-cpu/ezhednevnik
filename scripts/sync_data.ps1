# Sync CURSOR markdown -> planner.json (ASCII-only source for encoding safety)
$ErrorActionPreference = "Stop"

$CursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Output = Join-Path (Split-Path $PSScriptRoot -Parent) "data\planner.json"
$DailyFolder = [string][char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043D + [char]0x0435 + [char]0x0432 + [char]0x043D + [char]0x0438 + [char]0x043A
$CalendarName = [string][char]0x041A + [char]0x0410 + [char]0x041B + [char]0x0415 + [char]0x041D + [char]0x0414 + [char]0x0410 + [char]0x0420 + [char]0x042C + '.md'

function Get-Domain([string]$Path) {
    $rel = $Path.Substring($CursorRoot.Length).TrimStart('\', '/')
    return ($rel -split '[\\/]')[0]
}

function Get-Cells([string]$Line) {
    if (-not $Line.StartsWith('|')) { return $null }
    if ($Line -match '^\|[\s\-:|]+\|$') { return $null }
    return @(($Line -split '\|')[1..($Line.Split('|').Count - 2)] | ForEach-Object { $_.Trim().Trim('*') })
}

function Parse-Backlog([string]$Path) {
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $name = Split-Path (Split-Path $Path -Parent) -Leaf
    $tasks = [System.Collections.ArrayList]@()
    $inBacklog = $false

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -eq '## Backlog') { $inBacklog = $true; continue }
        if ($inBacklog -and $t -match '^## ') { $inBacklog = $false }
        $cells = Get-Cells $t
        if ($inBacklog -and $cells -and $cells.Count -ge 5 -and $cells[0] -match '\d' -and $cells[0] -ne 'ID') {
            [void]$tasks.Add(@{
                id = $cells[0]; title = $cells[1]; priority = $cells[2]
                status = $cells[3]; assignee = $(if ($cells.Count -gt 4) { $cells[4] } else { '' })
            })
        }
    }

    return @{
        name = $name
        path = $Path.Substring($CursorRoot.Length).TrimStart('\', '/')
        domain = Get-Domain $Path
        tasks = $tasks
    }
}

function Parse-Calendar([string]$Path) {
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $events = [System.Collections.ArrayList]@()
    $deadlines = [System.Collections.ArrayList]@()
    $tableMode = $null

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '^## ') { $tableMode = $null; continue }
        $cells = Get-Cells $t
        if (-not $cells -or $cells.Count -lt 4) { continue }
        if ($cells[0].Length -lt 6) { continue }

        if ($null -eq $tableMode) {
            if ($cells.Count -ge 6) { $tableMode = 'events' }
            elseif ($cells.Count -eq 5) { $tableMode = 'deadlines' }
            else { continue }
        }

        if ($tableMode -eq 'events' -and $cells.Count -ge 6) {
            $time = $cells[1]
            if ($time -notmatch '^\d{1,2}:\d{2}') { $time = $null }
            [void]$events.Add(@{
                date = $cells[0]; time = $time
                client = $cells[2]; type = $cells[3]; title = $cells[4]; status = $cells[5]
            })
        }
        if ($tableMode -eq 'deadlines' -and $cells.Count -ge 4) {
            [void]$deadlines.Add(@{
                date = $cells[0]; client = $cells[1]; event = $cells[2]; status = $cells[3]
            })
        }
    }

    return @{
        path = $Path.Substring($CursorRoot.Length).TrimStart('\', '/')
        domain = Get-Domain $Path
        events = $events
        deadlines = $deadlines
    }
}

$clients = [System.Collections.ArrayList]@()
$calendars = [System.Collections.ArrayList]@()
$domains = @{}

Get-ChildItem -Path $CursorRoot -Recurse -Filter "BACKLOG.md" |
    Where-Object { $_.FullName -notmatch $DailyFolder } |
    ForEach-Object {
        $c = Parse-Backlog $_.FullName
        [void]$clients.Add($c)
        $domains[$c.domain] = $true
    }

Get-ChildItem -Path $CursorRoot -Recurse -Filter $CalendarName |
    Where-Object { $_.FullName -notmatch $DailyFolder } |
    ForEach-Object {
        $cal = Parse-Calendar $_.FullName
        [void]$calendars.Add($cal)
        $domains[$cal.domain] = $true
    }

$allTasks = @($clients | ForEach-Object { $_.tasks })

$data = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    cursor_root = $CursorRoot
    stats = [ordered]@{
        clients = $clients.Count
        tasks = $allTasks.Count
        upcoming_events = ($calendars | ForEach-Object { $_.events.Count } | Measure-Object -Sum).Sum
    }
    domains = @($domains.Keys | Sort-Object)
    clients = @($clients | Sort-Object name)
    calendars = $calendars
}

$outDir = Split-Path $Output -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$json = $data | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($Output, $json, [System.Text.UTF8Encoding]::new($false))

$WebOutput = Join-Path (Split-Path $PSScriptRoot -Parent) "web\data\planner.json"
$webDir = Split-Path $WebOutput -Parent
if (-not (Test-Path $webDir)) { New-Item -ItemType Directory -Path $webDir -Force | Out-Null }
[System.IO.File]::WriteAllText($WebOutput, $json, [System.Text.UTF8Encoding]::new($false))

# Mirror web -> docs (GitHub Pages: deploy from branch /docs)
$RepoRoot = Split-Path $PSScriptRoot -Parent
$WebFolder = Join-Path $RepoRoot "web"
$DocsFolder = Join-Path $RepoRoot "docs"
if (Test-Path $WebFolder) {
    if (Test-Path $DocsFolder) { Remove-Item $DocsFolder -Recurse -Force }
    Copy-Item $WebFolder $DocsFolder -Recurse
}

Write-Host ("OK: " + $Output + " + web/data + docs | clients=" + $clients.Count + " tasks=" + $allTasks.Count)
