# Sanitize planner.json for public Git / GitHub Pages (ASCII-only source)
param([Parameter(Mandatory)][object]$Data)

function Strip-SensitiveText([string]$Text, [string[]]$ClientNames) {
    if (-not $Text) { return $Text }
    $t = $Text
    foreach ($name in ($ClientNames | Sort-Object { $_.Length } -Descending)) {
        if ($name -and $name.Length -gt 2) {
            $t = $t -replace [regex]::Escape($name), '[client]'
        }
    }
    $t = [regex]::Replace($t, '@[\w\.\-]+', '[messenger]')
    $t = [regex]::Replace($t, '\+?\d[\d\s\-\(\)]{8,}\d', '[redacted]')
    $t = [regex]::Replace($t, '[\w.\-]+@[\w.\-]+\.\w+', '[redacted]')
    $t = [regex]::Replace($t, '\d+[\s\u00a0]*(?:RUB|USD|EUR|\$)', '[amount]')
    $t = [regex]::Replace($t, '(?i)\d+[\s]*K/mes', '[amount]')
    $t = [regex]::Replace($t, '\d+[\s\u00a0]*\u20bd', '[amount]')
    $t = [regex]::Replace($t, '(?i)\d+\s*(?:tys|k)\s*/\s*mes', '[amount]')
    return $t
}

function Sanitize-Assignee([string]$Name) {
    if (-not $Name -or $Name -eq [char]0x2014 -or $Name -eq '-') { return $null }
    return $Name.Trim()
}

$clientNames = @($Data.clients | ForEach-Object { $_.name } | Where-Object { $_ })

$idx = 0
$publicClients = [System.Collections.ArrayList]@()
foreach ($c in ($Data.clients | Sort-Object { $_.name })) {
    $idx++
    $code = 'P-{0:D2}' -f $idx
    $publicTasks = [System.Collections.ArrayList]@()
    $high = 0
    $active = 0
    foreach ($task in @($c.tasks)) {
        if ($task.priority -match '(?i)vysok|high|\u0432\u044b\u0441\u043e\u043a') { $high++ }
        if ($task.status -match '(?i)vypoln|work|\u0432\u044b\u043f\u043e\u043b\u043d|\u0440\u0430\u0431\u043e\u0442') { $active++ }
        $assignee = Sanitize-Assignee $task.assignee
        [void]$publicTasks.Add([ordered]@{
            id = $task.id
            title = (Strip-SensitiveText $task.title $clientNames)
            priority = $task.priority
            status = $task.status
            assignee = $assignee
        })
    }
    [void]$publicClients.Add([ordered]@{
        id = $code
        domain = $c.domain
        task_count = $publicTasks.Count
        high_priority = $high
        active = $active
        tasks = $publicTasks
    })
}

$publicEvents = [System.Collections.ArrayList]@()
foreach ($cal in $Data.calendars) {
    foreach ($e in $cal.events) {
        if ($e.date -match 'GGGG' -or $e.client -match '^\[') { continue }
        [void]$publicEvents.Add([ordered]@{
            date = $e.date
            time = $e.time
            type = (Strip-SensitiveText $e.type $clientNames)
            title = (Strip-SensitiveText $e.title $clientNames)
            status = $e.status
        })
    }
    foreach ($d in $cal.deadlines) {
        [void]$publicEvents.Add([ordered]@{
            date = $d.date
            type = 'deadline'
            title = (Strip-SensitiveText $d.event $clientNames)
            status = $d.status
        })
    }
}

$overdue = 0
foreach ($cal in $Data.calendars) {
    foreach ($d in $cal.deadlines) {
        if ($d.status -match '(?i)prosroch|\u043f\u0440\u043e\u0441\u0440\u043e\u0447') { $overdue++ }
    }
}

return [ordered]@{
    generated_at = $Data.generated_at
    privacy = 'public'
    notice = 'Public snapshot: FIO allowed. No phones, emails, clients, amounts.'
    stats = [ordered]@{
        clients = $publicClients.Count
        tasks = $Data.stats.tasks
        upcoming_events = $Data.stats.upcoming_events
        overdue_deadlines = $overdue
    }
    domains = $Data.domains
    clients = $publicClients
    events = $publicEvents
}
