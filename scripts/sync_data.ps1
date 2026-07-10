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
    $contacts = @{}
    $status = $null
    $inBacklog = $false
    $kOrg = [string][char]0x041e + [char]0x0440 + [char]0x0433 + [char]0x0430 + [char]0x043d + [char]0x0438 + [char]0x0437 + [char]0x0430 + [char]0x0446 + [char]0x0438 + [char]0x044f
    $kContact = [string][char]0x041a + [char]0x043e + [char]0x043d + [char]0x0442 + [char]0x0430 + [char]0x043a + [char]0x0442
    $kPhone = [string][char]0x0422 + [char]0x0435 + [char]0x043b + [char]0x0435 + [char]0x0444 + [char]0x043e + [char]0x043d
    $kCity = [string][char]0x0413 + [char]0x043e + [char]0x0440 + [char]0x043e + [char]0x0434
    $kType = [string][char]0x0422 + [char]0x0438 + [char]0x043f
    $kStage = [string][char]0x042d + [char]0x0442 + [char]0x0430 + [char]0x043f

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -eq '## Backlog') { $inBacklog = $true; continue }
        if ($inBacklog -and $t -match '^## ') { $inBacklog = $false }
        $cells = Get-Cells $t
        if ($cells -and $cells.Count -ge 2) {
            if ($cells[0] -eq $kStage) { $status = $cells[1] }
            if ($cells[0] -in @($kOrg, $kContact, $kPhone, $kCity, $kType)) {
                $contacts[$cells[0]] = $cells[1]
            }
        }
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
        status = $status
        contacts = $contacts
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

$RepoRoot = Split-Path $PSScriptRoot -Parent
$fullJson = $data | ConvertTo-Json -Depth 10

# Full snapshot — local only (gitignored)
$LocalOutput = Join-Path $outDir "planner.local.json"
[System.IO.File]::WriteAllText($LocalOutput, $fullJson, [System.Text.UTF8Encoding]::new($false))

$WebLocal = Join-Path $RepoRoot "web\data\planner.local.json"
$webDataDir = Split-Path $WebLocal -Parent
if (-not (Test-Path $webDataDir)) { New-Item -ItemType Directory -Path $webDataDir -Force | Out-Null }
[System.IO.File]::WriteAllText($WebLocal, $fullJson, [System.Text.UTF8Encoding]::new($false))

# Sanitized snapshot — safe for Git / GitHub Pages
$publicData = & (Join-Path $PSScriptRoot "sanitize_planner.ps1") -Data $data
$publicJson = $publicData | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($Output, $publicJson, [System.Text.UTF8Encoding]::new($false))

$WebOutput = Join-Path $RepoRoot "web\data\planner.json"
[System.IO.File]::WriteAllText($WebOutput, $publicJson, [System.Text.UTF8Encoding]::new($false))

# Mirror web -> docs (Pages); planner.json in docs is already sanitized
$WebFolder = Join-Path $RepoRoot "web"
$DocsFolder = Join-Path $RepoRoot "docs"
if (Test-Path $WebFolder) {
    if (Test-Path $DocsFolder) { Remove-Item $DocsFolder -Recurse -Force }
    Copy-Item $WebFolder $DocsFolder -Recurse
    if (Test-Path (Join-Path $DocsFolder "data\planner.local.json")) {
        Remove-Item (Join-Path $DocsFolder "data\planner.local.json") -Force
    }
}

Write-Host ("OK: local + public snapshots | clients=" + $clients.Count + " tasks=" + $allTasks.Count)
