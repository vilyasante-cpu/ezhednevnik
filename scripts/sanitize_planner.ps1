# Sanitize planner.json for Git / GitHub Pages
# Allowed: FIO, companies, employees, client names
# Blocked: phones, emails, amounts, local machine paths
param([Parameter(Mandatory)][object]$Data)

function Strip-SensitiveText([string]$Text) {
    if (-not $Text) { return $Text }
    $t = $Text
    $t = [regex]::Replace($t, '\+?\d[\d\s\-\(\)]{8,}\d', '[tel]')
    $t = [regex]::Replace($t, '[\w.\-]+@[\w.\-]+\.\w+', '[email]')
    $t = [regex]::Replace($t, '\d+[\s\u00a0]*(?:RUB|USD|EUR|\$|\u20bd)', '[amount]')
    $t = [regex]::Replace($t, '(?i)\d+[\s]*K/[\u043c\u043c]?es', '[amount]')
    $t = [regex]::Replace($t, '(?i)\d+\s*(?:\u0442\u044b\u0441\.?|tys\.?)\s*\u20bd', '[amount]')
    return $t
}

function Sanitize-Assignee([string]$Name) {
    if (-not $Name -or $Name -eq [char]0x2014 -or $Name -eq '-') { return $null }
    return (Strip-SensitiveText $Name.Trim())
}

function Sanitize-Contacts([hashtable]$Contacts) {
    if (-not $Contacts) { return @{} }
    $out = @{}
    $phoneKey = [string][char]0x0422 + [char]0x0435 + [char]0x043b + [char]0x0435 + [char]0x0444 + [char]0x043e + [char]0x043d
    foreach ($key in $Contacts.Keys) {
        if ($key -eq $phoneKey) { continue }
        $out[$key] = Strip-SensitiveText $Contacts[$key]
    }
    return $out
}

$publicClients = [System.Collections.ArrayList]@()
foreach ($c in ($Data.clients | Sort-Object { $_.name })) {
    $publicTasks = [System.Collections.ArrayList]@()
    foreach ($task in @($c.tasks)) {
        [void]$publicTasks.Add([ordered]@{
            id = $task.id
            title = (Strip-SensitiveText $task.title)
            priority = $task.priority
            status = $task.status
            assignee = (Sanitize-Assignee $task.assignee)
        })
    }
    [void]$publicClients.Add([ordered]@{
        name = $c.name
        domain = $c.domain
        project_status = $c.project_status
        deal_stage = $c.deal_stage
        contacts = (Sanitize-Contacts $c.contacts)
        tasks = $publicTasks
    })
}

$publicCalendars = [System.Collections.ArrayList]@()
foreach ($cal in $Data.calendars) {
    $events = [System.Collections.ArrayList]@()
    $deadlines = [System.Collections.ArrayList]@()
    foreach ($e in $cal.events) {
        if ($e.date -match 'GGGG' -or $e.client -match '^\[') { continue }
        [void]$events.Add([ordered]@{
            key = $e.key
            date = $e.date
            time = $e.time
            client = (Strip-SensitiveText $e.client)
            type = (Strip-SensitiveText $e.type)
            title = (Strip-SensitiveText $e.title)
            status = $e.status
            closed = [bool]$e.closed
        })
    }
    foreach ($d in $cal.deadlines) {
        [void]$deadlines.Add([ordered]@{
            key = $d.key
            date = $d.date
            client = (Strip-SensitiveText $d.client)
            event = (Strip-SensitiveText $d.event)
            status = $d.status
            closed = [bool]$d.closed
        })
    }
    [void]$publicCalendars.Add([ordered]@{
        domain = $cal.domain
        events = $events
        deadlines = $deadlines
    })
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
    notice = 'Names and companies allowed. Phones, emails, amounts removed.'
    stats = [ordered]@{
        clients = $publicClients.Count
        tasks = $Data.stats.tasks
        upcoming_events = $Data.stats.upcoming_events
        overdue_deadlines = $overdue
    }
    domains = $Data.domains
    clients = $publicClients
    calendars = $publicCalendars
}
