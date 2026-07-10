# Shared calendar helpers (sync + close write-back)

function Get-RawCells([string]$Line) {
    if (-not $Line -or -not $Line.Trim().StartsWith('|')) { return $null }
    if ($Line.Trim() -match '^\|[\s\-:|]+\|$') { return $null }
    $parts = $Line.Trim() -split '\|'
    if ($parts.Count -lt 3) { return $null }
    $cells = [System.Collections.ArrayList]@()
    for ($i = 1; $i -lt $parts.Count - 1; $i++) {
        [void]$cells.Add($parts[$i])
    }
    return ,@($cells.ToArray())
}

function Strip-MdText([string]$Text) {
    if (-not $Text) { return '' }
    $t = $Text.Trim()
    $t = $t -replace '~~', ''
    $t = $t -replace '\*\*', ''
    $t = $t.Trim('*').Trim()
    return $t
}

function Normalize-KeyPart([string]$s) {
    if (-not $s) { return '' }
    return (Strip-MdText $s).ToLowerInvariant()
}

function Get-EventKey([string]$Domain, [string]$Source, [string]$Date, [string]$Client, [string]$Title, [string]$Type) {
    $parts = @(
        (Normalize-KeyPart $Domain),
        (Normalize-KeyPart $Source),
        (Normalize-KeyPart $Date),
        (Normalize-KeyPart $Client),
        (Normalize-KeyPart $Title),
        (Normalize-KeyPart $Type)
    ) -join '|'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').Substring(0, 16).ToLower()
}

function Test-LineClosed([string]$Line, [string]$StatusText) {
    if ($Line -and $Line -match '~~') { return $true }
    $s = Strip-MdText $StatusText
    if ($s -match '(?i)^\u0432\u044b\u043f\u043e\u043b\u043d') { return $true }
    return $false
}

function Wrap-StrikeCell([string]$Cell) {
    $c = $Cell.Trim()
    if ($c -match '~~') { return $Cell }
    if (-not $c -or $c -eq [char]0x2014 -or $c -eq '-') { return $Cell }
    return " ~~$c~~ "
}

function Get-CalendarSection([string]$Line) {
    $t = $Line.Trim()
    if ($t -notmatch '^## ') { return $null }
    $kUpcoming = [string][char]0x041f + [char]0x0440 + [char]0x0435 + [char]0x0434 + [char]0x0441 + [char]0x0442 + [char]0x043e + [char]0x044f + [char]0x0449 + [char]0x0438 + [char]0x0435
    $kDeadlines = [string][char]0x041a + [char]0x043e + [char]0x043d + [char]0x0442 + [char]0x0440 + [char]0x043e + [char]0x043b + [char]0x044c + [char]0x043d + [char]0x044b + [char]0x0435
    $kPast = [string][char]0x041f + [char]0x0440 + [char]0x043e + [char]0x0448 + [char]0x0435 + [char]0x0434 + [char]0x0448 + [char]0x0438 + [char]0x0435
    if ($t.Contains($kUpcoming)) { return 'upcoming' }
    if ($t.Contains($kDeadlines)) { return 'deadlines' }
    if ($t.Contains($kPast)) { return 'past' }
    return 'other'
}

function Close-CalendarRowLine([string]$Line, [string]$Section, [string]$Outcome) {
    $rawCells = Get-RawCells $Line
    if (-not $rawCells) { return $Line }

    $cells = $rawCells | ForEach-Object { Strip-MdText $_ }
    if ($cells.Count -lt 4 -or $cells[0] -notmatch '\d') { return $Line }

    $kDone = [string][char]0x0412 + [char]0x044b + [char]0x043f + [char]0x043e + [char]0x043b + [char]0x043d + [char]0x0435 + [char]0x043d + [char]0x043e
    $kClosedNote = [string][char]0x0417 + [char]0x0430 + [char]0x043a + [char]0x0440 + [char]0x044b + [char]0x0442 + [char]0x043e + ' ' + [char]0x0438 + [char]0x0437 + ' ' + [char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043d + [char]0x0435 + [char]0x0432 + [char]0x043d + [char]0x0438 + [char]0x043a + [char]0x0430
    $closedAt = Get-Date -Format 'dd.MM.yyyy'

    if ($Section -eq 'upcoming' -and $cells.Count -ge 6) {
        for ($i = 0; $i -lt 5; $i++) {
            $rawCells[$i] = Wrap-StrikeCell $rawCells[$i]
        }
        $rawCells[5] = " **$kDone** "
        if ($rawCells.Count -gt 6) {
            $note = if ($Outcome) { $Outcome } else { "$kClosedNote $closedAt" }
            $rawCells[6] = " $note "
        }
    }
    elseif ($Section -eq 'deadlines' -and $cells.Count -ge 4) {
        for ($i = 0; $i -lt 3; $i++) {
            $rawCells[$i] = Wrap-StrikeCell $rawCells[$i]
        }
        $rawCells[3] = " $kDone "
        if ($Outcome -and $rawCells.Count -gt 4) {
            $rawCells[4] = " $Outcome "
        }
        elseif ($Outcome) {
            $rawCells += " $Outcome "
        }
    }
    else {
        return $Line
    }

    return '|' + ($rawCells -join '|') + '|'
}

function Close-EventInCalendarFile([string]$Path, [string]$Key, [string]$Domain, [string]$Outcome) {
    $lines = [System.Collections.ArrayList]@([System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8))
    $section = $null
    $found = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $sec = Get-CalendarSection $line
        if ($sec) {
            if ($sec -eq 'upcoming' -or $sec -eq 'deadlines' -or $sec -eq 'past') {
                $section = $sec
            }
            elseif ($section -eq 'upcoming') {
                $section = $null
            }
            continue
        }
        if ($section -eq 'past') { continue }

        $rawCells = Get-RawCells $line
        if (-not $rawCells) { continue }
        $cells = $rawCells | ForEach-Object { Strip-MdText $_ }
        if ($cells.Count -lt 4 -or $cells[0] -notmatch '\d') { continue }

        $rowKey = $null
        if ($section -eq 'upcoming' -and $cells.Count -ge 6) {
            $rowKey = Get-EventKey $Domain 'event' $cells[0] $cells[2] $cells[4] $cells[3]
        }
        elseif ($section -eq 'deadlines' -and $cells.Count -ge 4) {
            $rowKey = Get-EventKey $Domain 'deadline' $cells[0] $cells[1] $cells[2] ''
        }
        else {
            continue
        }

        if ($rowKey -ne $Key) { continue }
        $statusIdx = if ($section -eq 'upcoming') { 5 } else { 3 }
        if (Test-LineClosed $line $cells[$statusIdx]) {
            return @{ ok = $true; already = $true; path = $Path }
        }

        $lines[$i] = Close-CalendarRowLine $line $section $Outcome
        $found = $true
        break
    }

    if (-not $found) { return $null }

    [System.IO.File]::WriteAllLines($Path, $lines.ToArray(), [System.Text.UTF8Encoding]::new($false))
    return @{ ok = $true; path = $Path; key = $Key }
}
