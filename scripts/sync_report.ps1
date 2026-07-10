# Build and print sync transfer reports

function Get-SnapshotMetrics([object]$Clients, [object]$Calendars) {
    $events = 0
    $deadlines = 0
    $closedEvents = 0
    $closedDeadlines = 0
    $overdue = 0

    foreach ($cal in @($Calendars)) {
        foreach ($e in @($cal.events)) {
            $events++
            if ($e.closed) { $closedEvents++ }
        }
        foreach ($d in @($cal.deadlines)) {
            $deadlines++
            if ($d.closed) { $closedDeadlines++ }
            if ($d.status -match '(?i)prosroch|\u043f\u0440\u043e\u0441\u0440\u043e\u0447') { $overdue++ }
        }
    }

    $statusBreakdown = @{}
    foreach ($c in @($Clients)) {
        $st = if ($c.project_status) { $c.project_status } else { 'No status' }
        if (-not $statusBreakdown.ContainsKey($st)) { $statusBreakdown[$st] = 0 }
        $statusBreakdown[$st]++
    }

    return [ordered]@{
        clients = @($Clients).Count
        tasks = (@($Clients) | ForEach-Object { @($_.tasks).Count } | Measure-Object -Sum).Sum
        events = $events
        deadlines = $deadlines
        closed_events = $closedEvents
        closed_deadlines = $closedDeadlines
        overdue_deadlines = $overdue
        status_breakdown = $statusBreakdown
    }
}

function Get-MetricsFromPlanner([object]$Planner) {
    if (-not $Planner) { return $null }
    $events = 0
    $deadlines = 0
    $closedEvents = 0
    $closedDeadlines = 0
    $overdue = 0
    $statusBreakdown = @{}

    foreach ($cal in @($Planner.calendars)) {
        foreach ($e in @($cal.events)) {
            $events++
            if ($e.closed) { $closedEvents++ }
        }
        foreach ($d in @($cal.deadlines)) {
            $deadlines++
            if ($d.closed) { $closedDeadlines++ }
            if ($d.status -match '(?i)prosroch|\u043f\u0440\u043e\u0441\u0440\u043e\u0447') { $overdue++ }
        }
    }
    foreach ($c in @($Planner.clients)) {
        $st = if ($c.project_status) { $c.project_status } else { 'No status' }
        if (-not $statusBreakdown.ContainsKey($st)) { $statusBreakdown[$st] = 0 }
        $statusBreakdown[$st]++
    }

    return [ordered]@{
        clients = [int]$Planner.stats.clients
        tasks = [int]$Planner.stats.tasks
        events = $events
        deadlines = $deadlines
        closed_events = $closedEvents
        closed_deadlines = $closedDeadlines
        overdue_deadlines = $overdue
        status_breakdown = $statusBreakdown
    }
}

function Get-MetricDelta([int]$Old, [int]$New) {
    $delta = $New - $Old
    if ($delta -gt 0) { return "+$delta" }
    if ($delta -lt 0) { return "$delta" }
    return "0"
}

function Build-SyncReport {
    param(
        [object]$Clients,
        [object]$Calendars,
        [string[]]$Domains,
        [int]$BacklogFiles,
        [int]$CalendarFiles,
        [object]$PreviousPlanner,
        [string[]]$Outputs
    )

    $current = Get-SnapshotMetrics $Clients $Calendars
    $previous = Get-MetricsFromPlanner $PreviousPlanner
    $changes = @{}

    if ($previous) {
        $changes = [ordered]@{
            clients = Get-MetricDelta $previous.clients $current.clients
            tasks = Get-MetricDelta $previous.tasks $current.tasks
            events = Get-MetricDelta $previous.events $current.events
            deadlines = Get-MetricDelta $previous.deadlines $current.deadlines
        }
        $hasChanges = $changes.clients -ne '0' -or $changes.tasks -ne '0' -or $changes.events -ne '0' -or $changes.deadlines -ne '0'
    } else {
        $hasChanges = $true
        $changes = [ordered]@{
            clients = 'new'
            tasks = 'new'
            events = 'new'
            deadlines = 'new'
        }
    }

    return [ordered]@{
        status = 'ok'
        generated_at = (Get-Date).ToUniversalTime().ToString('o')
        previous_sync_at = if ($PreviousPlanner) { $PreviousPlanner.generated_at } else { $null }
        sources = [ordered]@{
            backlog_files = $BacklogFiles
            calendar_files = $CalendarFiles
            domains = @($Domains | Sort-Object)
        }
        transferred = [ordered]@{
            clients = $current.clients
            tasks = $current.tasks
            events = $current.events
            deadlines = $current.deadlines
            closed_events = $current.closed_events
            closed_deadlines = $current.closed_deadlines
            overdue_deadlines = $current.overdue_deadlines
            project_status = $current.status_breakdown
        }
        changes = $changes
        has_changes = $hasChanges
        outputs = $Outputs
    }
}

function Write-SyncReportHost([object]$Report) {
    $kClients = [string][char]0x041a + [char]0x043b + [char]0x0438 + [char]0x0435 + [char]0x043d + [char]0x0442 + [char]0x044b
    $kTasks = [string][char]0x0417 + [char]0x0430 + [char]0x0434 + [char]0x0430 + [char]0x0447 + [char]0x0438
    $kEvents = [string][char]0x0421 + [char]0x043e + [char]0x0431 + [char]0x044b + [char]0x0442 + [char]0x0438 + [char]0x044f
    $kDeadlines = [string][char]0x0414 + [char]0x0435 + [char]0x0434 + [char]0x043b + [char]0x0430 + [char]0x0439 + [char]0x043d + [char]0x044b
    $kDone = [string][char]0x0421 + [char]0x0438 + [char]0x043d + [char]0x0445 + [char]0x0440 + [char]0x043e + [char]0x043d + [char]0x0438 + [char]0x0437 + [char]0x0430 + [char]0x0446 + [char]0x0438 + [char]0x044f + ' ' + [char]0x0437 + [char]0x0430 + [char]0x0432 + [char]0x0435 + [char]0x0440 + [char]0x0448 + [char]0x0435 + [char]0x043d + [char]0x0430
    $kTransferred = [string][char]0x041f + [char]0x0435 + [char]0x0440 + [char]0x0435 + [char]0x0434 + [char]0x0430 + [char]0x043d + [char]0x043e + ' ' + [char]0x0432 + ' planner.json'
    $kSources = [string][char]0x0418 + [char]0x0441 + [char]0x0442 + [char]0x043e + [char]0x0447 + [char]0x043d + [char]0x0438 + [char]0x043a + [char]0x0438
    $kChanges = [string][char]0x0418 + [char]0x0437 + [char]0x043c + [char]0x0435 + [char]0x043d + [char]0x0435 + [char]0x043d + [char]0x0438 + [char]0x044f + ' ' + [char]0x0441 + ' ' + [char]0x043f + [char]0x0440 + [char]0x043e + [char]0x0448 + [char]0x043b + [char]0x043e + [char]0x0439 + ' ' + [char]0x0432 + [char]0x044b + [char]0x0433 + [char]0x0440 + [char]0x0443 + [char]0x0437 + [char]0x043a + [char]0x0438
    $kFiles = [string][char]0x0424 + [char]0x0430 + [char]0x0439 + [char]0x043b + [char]0x044b
    $kNoChanges = [string][char]0x0411 + [char]0x0435 + [char]0x0437 + ' ' + [char]0x0438 + [char]0x0437 + [char]0x043c + [char]0x0435 + [char]0x043d + [char]0x0435 + [char]0x043d + [char]0x0438 + [char]0x0439 + ' ' + [char]0x0432 + ' ' + [char]0x0441 + [char]0x0447 + [char]0x0451 + [char]0x0442 + [char]0x0447 + [char]0x0438 + [char]0x043a + [char]0x0430 + [char]0x0445

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  $kDone" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "${kSources}:" -ForegroundColor Cyan
    Write-Host ("  BACKLOG.md:    " + $Report.sources.backlog_files)
    Write-Host ("  Calendar:      " + $Report.sources.calendar_files)
    Write-Host ("  Domains:       " + ($Report.sources.domains -join ', '))
    Write-Host ""
    Write-Host "$kTransferred" -ForegroundColor Cyan
    Write-Host ("  $kClients`:      " + $Report.transferred.clients)
    Write-Host ("  $kTasks`:        " + $Report.transferred.tasks)
    Write-Host ("  $kEvents`:       " + $Report.transferred.events + " (closed: " + $Report.transferred.closed_events + ")")
    Write-Host ("  $kDeadlines`:    " + $Report.transferred.deadlines + " (overdue: " + $Report.transferred.overdue_deadlines + ")")
    if ($Report.transferred.project_status) {
        Write-Host "  Project status:"
        foreach ($key in ($Report.transferred.project_status.Keys | Sort-Object)) {
            Write-Host ("    - " + $key + ": " + $Report.transferred.project_status[$key])
        }
    }
    Write-Host ""
    Write-Host "$kChanges" -ForegroundColor Cyan
    if ($Report.has_changes) {
        Write-Host ("  $kClients`:      " + $Report.changes.clients)
        Write-Host ("  $kTasks`:        " + $Report.changes.tasks)
        Write-Host ("  $kEvents`:       " + $Report.changes.events)
        Write-Host ("  $kDeadlines`:    " + $Report.changes.deadlines)
    } else {
        Write-Host "  $kNoChanges" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "${kFiles}:" -ForegroundColor Cyan
    foreach ($f in $Report.outputs) {
        Write-Host ("  -> " + $f) -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Write-GitSyncReportHost {
    param(
        [bool]$Committed,
        [string]$CommitMsg,
        [string]$CommitHash,
        [bool]$Pushed,
        [string[]]$ChangedFiles,
        [bool]$Skipped
    )

    $kGit = 'Git'
    $kSkip = [string][char]0x041d + [char]0x0435 + [char]0x0442 + ' ' + [char]0x0438 + [char]0x0437 + [char]0x043c + [char]0x0435 + [char]0x043d + [char]0x0435 + [char]0x043d + [char]0x0438 + [char]0x0439 + ' - ' + [char]0x043f + [char]0x0443 + [char]0x0431 + [char]0x043b + [char]0x0438 + [char]0x043a + [char]0x0430 + [char]0x0446 + [char]0x0438 + [char]0x044f + ' ' + [char]0x043d + [char]0x0435 + ' ' + [char]0x0442 + [char]0x0440 + [char]0x0435 + [char]0x0431 + [char]0x0443 + [char]0x0435 + [char]0x0442 + [char]0x0441 + [char]0x044f
    $kPushOk = [string][char]0x041e + [char]0x0442 + [char]0x043f + [char]0x0440 + [char]0x0430 + [char]0x0432 + [char]0x043b + [char]0x0435 + [char]0x043d + [char]0x043e + ' ' + [char]0x0432 + ' origin/main'

    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  $kGit" -ForegroundColor Cyan
    if ($Skipped) {
        Write-Host "  $kSkip" -ForegroundColor DarkGray
    } else {
        if ($Committed) {
            Write-Host ("  Commit: " + $CommitHash + " " + $CommitMsg) -ForegroundColor Green
            foreach ($f in $ChangedFiles) {
                Write-Host ("    ~ " + $f) -ForegroundColor DarkGray
            }
        }
        if ($Pushed) {
            Write-Host "  $kPushOk" -ForegroundColor Green
        }
    }
    Write-Host ""
}
