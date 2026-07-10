# Sync CURSOR markdown -> planner.json (ASCII-only source for encoding safety)
$ErrorActionPreference = "Stop"

$CursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Output = Join-Path (Split-Path $PSScriptRoot -Parent) "data\planner.json"
$DailyFolder = [string][char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043D + [char]0x0435 + [char]0x0432 + [char]0x043D + [char]0x0438 + [char]0x043A
$CalendarName = [string][char]0x041A + [char]0x0410 + [char]0x041B + [char]0x0415 + [char]0x041D + [char]0x0414 + [char]0x0410 + [char]0x0420 + [char]0x042C + '.md'

. (Join-Path $PSScriptRoot 'calendar_lib.ps1')
. (Join-Path $PSScriptRoot 'sync_report.ps1')

function Get-Domain([string]$Path) {
    $rel = $Path.Substring($CursorRoot.Length).TrimStart('\', '/')
    return ($rel -split '[\\/]')[0]
}

. (Join-Path $PSScriptRoot 'backlog_lib.ps1')

function Parse-Calendar([string]$Path) {
    $domain = Get-Domain $Path
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $events = [System.Collections.ArrayList]@()
    $deadlines = [System.Collections.ArrayList]@()
    $section = $null

    foreach ($line in $lines) {
        $t = $line.Trim()
        $sec = Get-CalendarSection $t
        if ($sec) {
            if ($sec -in @('upcoming', 'deadlines', 'past')) { $section = $sec }
            elseif ($section -eq 'upcoming') { $section = $null }
            continue
        }
        if ($section -eq 'past') { continue }

        $rawCells = Get-RawCells $t
        if (-not $rawCells) { continue }
        $cells = $rawCells | ForEach-Object { Strip-MdText $_ }
        if ($cells.Count -lt 4 -or $cells[0] -notmatch '\d') { continue }

        if ($section -eq 'upcoming' -and $cells.Count -ge 6) {
            $time = $cells[1]
            if ($time -notmatch '^\d{1,2}:\d{2}') { $time = $null }
            $closed = Test-LineClosed $t $cells[5]
            $key = Get-EventKey $domain 'event' $cells[0] $cells[2] $cells[4] $cells[3]
            [void]$events.Add(@{
                key = $key
                date = $cells[0]; time = $time
                client = $cells[2]; type = $cells[3]; title = $cells[4]; status = $cells[5]
                comment = $(if ($cells.Count -gt 6) { $cells[6] } else { '' })
                closed = $closed
            })
        }
        elseif ($section -eq 'deadlines' -and $cells.Count -ge 4) {
            $closed = Test-LineClosed $t $cells[3]
            $key = Get-EventKey $domain 'deadline' $cells[0] $cells[1] $cells[2] ''
            [void]$deadlines.Add(@{
                key = $key
                date = $cells[0]; client = $cells[1]; event = $cells[2]; status = $cells[3]
                comment = $(if ($cells.Count -gt 4) { $cells[4] } else { '' })
                closed = $closed
            })
        }
    }

    return @{
        path = $Path.Substring($CursorRoot.Length).TrimStart('\', '/')
        domain = $domain
        events = $events
        deadlines = $deadlines
    }
}

$clients = [System.Collections.ArrayList]@()
$calendars = [System.Collections.ArrayList]@()
$domains = @{}
$backlogFiles = 0
$calendarFiles = 0

Get-ChildItem -Path $CursorRoot -Recurse -Filter "BACKLOG.md" |
    Where-Object { $_.FullName -notmatch $DailyFolder } |
    ForEach-Object {
        $backlogFiles++
        $c = Parse-Backlog $_.FullName $CursorRoot
        $c.domain = Get-Domain $_.FullName
        [void]$clients.Add($c)
        $domains[$c.domain] = $true
    }

Get-ChildItem -Path $CursorRoot -Recurse -Filter $CalendarName |
    Where-Object { $_.FullName -notmatch $DailyFolder } |
    ForEach-Object {
        $calendarFiles++
        $cal = Parse-Calendar $_.FullName
        [void]$calendars.Add($cal)
        $domains[$cal.domain] = $true
    }

$allTasks = @($clients | ForEach-Object { $_.tasks })

$previousPlanner = $null
if (Test-Path $Output) {
    try {
        $previousPlanner = Get-Content $Output -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { }
}

$syncReport = Build-SyncReport `
    -Clients $clients `
    -Calendars $calendars `
    -Domains @($domains.Keys) `
    -BacklogFiles $backlogFiles `
    -CalendarFiles $calendarFiles `
    -PreviousPlanner $previousPlanner `
    -Outputs @(
        'data/planner.json',
        'data/planner.local.json',
        'web/data/planner.json',
        'web/data/planner.local.json',
        'docs/'
    )

$data = [ordered]@{
    generated_at = $syncReport.generated_at
    cursor_root = $CursorRoot
    has_full_profiles = $true
    sync_report = $syncReport
    stats = [ordered]@{
        clients = $clients.Count
        tasks = $allTasks.Count
        upcoming_events = ($calendars | ForEach-Object { $_.events.Count } | Measure-Object -Sum).Sum
        deadlines = ($calendars | ForEach-Object { $_.deadlines.Count } | Measure-Object -Sum).Sum
    }
    domains = @($domains.Keys | Sort-Object)
    clients = @($clients | Sort-Object name)
    calendars = $calendars
}

$outDir = Split-Path $Output -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$RepoRoot = Split-Path $PSScriptRoot -Parent
$fullJson = $data | ConvertTo-Json -Depth 20

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

Write-SyncReportHost $syncReport

