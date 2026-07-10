# Full BACKLOG.md parser for local client profiles

function Get-BacklogCells([string]$Line) {
    if (-not $Line -or -not $Line.Trim().StartsWith('|')) { return $null }
    if ($Line.Trim() -match '^\|[\s\-:|]+\|$') { return $null }
    $parts = $Line.Trim() -split '\|'
    if ($parts.Count -lt 3) { return $null }
    $cells = [System.Collections.ArrayList]@()
    for ($i = 1; $i -lt $parts.Count - 1; $i++) {
        [void]$cells.Add(($parts[$i].Trim() -replace '\*\*', ''))
    }
    return ,@($cells.ToArray())
}

function New-ProfileSection([string]$Title) {
    return @{
        title = $Title
        blocks = [System.Collections.ArrayList]@()
    }
}

function Add-TextBlock($Section, [string]$Text) {
    if (-not $Text -or -not $Text.Trim()) { return }
    $last = if ($Section.blocks.Count -gt 0) { $Section.blocks[$Section.blocks.Count - 1] } else { $null }
    if ($last -and $last.kind -eq 'text') {
        $last.text = $last.text + "`n" + $Text.Trim()
    } else {
        [void]$Section.blocks.Add(@{ kind = 'text'; text = $Text.Trim() })
    }
}

function Flush-TableBuffer($Section, [System.Collections.ArrayList]$Buffer) {
    if ($Buffer.Count -eq 0) { return }
    $kStatus = [string][char]0x0421 + [char]0x0442 + [char]0x0430 + [char]0x0442 + [char]0x0443 + [char]0x0441
    $rows = @($Buffer | ForEach-Object { ,@($_) })
    $Buffer.Clear() | Out-Null

    $header = $rows[0]
    $dataRows = if ($rows.Count -gt 1) { $rows[1..($rows.Count - 1)] } else { @() }

    $isKeyValue = $false
    if ($header.Count -eq 2) {
        $h0 = $header[0].ToLower()
        $kField = [string][char]0x043f + [char]0x043e + [char]0x043b + [char]0x0435
        $kParam = [string][char]0x043f + [char]0x0430 + [char]0x0440 + [char]0x0430 + [char]0x043c + [char]0x0435 + [char]0x0442 + [char]0x0440
        if ($h0 -eq $kField -or $h0 -eq $kParam -or $h0 -eq $kStatus -or ($dataRows.Count -gt 0 -and $dataRows[0].Count -eq 2)) {
            $isKeyValue = $true
        }
    }

    if ($isKeyValue) {
        $kv = [System.Collections.ArrayList]@()
        $kHdrField = [string][char]0x041f + [char]0x043e + [char]0x043b + [char]0x0435
        $kHdrParam = [string][char]0x041f + [char]0x0430 + [char]0x0440 + [char]0x0430 + [char]0x043c + [char]0x0435 + [char]0x0442 + [char]0x0440
        $kHdrAllowed = [string][char]0x0414 + [char]0x043e + [char]0x043f + [char]0x0443 + [char]0x0441 + [char]0x0442 + [char]0x0438 + [char]0x043c + [char]0x044b + [char]0x0435
        foreach ($r in $rows) {
            if ($r.Count -ge 2 -and $r[0] -ne 'ID' -and $r[0] -ne $kHdrField -and $r[0] -ne $kHdrParam -and $r[0] -ne $kStatus -and $r[0] -ne $kHdrAllowed) {
                $val = ($r[1..($r.Count - 1)] -join ' | ')
                [void]$kv.Add(@($r[0], $val))
            }
        }
        if ($kv.Count -gt 0) {
            [void]$Section.blocks.Add(@{ kind = 'key_value'; rows = $kv.ToArray() })
        }
        return
    }

    if ($header.Count -ge 3) {
        [void]$Section.blocks.Add(@{
            kind = 'table'
            headers = $header
            rows = $dataRows
        })
        return
    }

    foreach ($r in $rows) {
        if ($r.Count -ge 2) {
            [void]$Section.blocks.Add(@{ kind = 'key_value'; rows = @(@($r[0], ($r[1..($r.Count - 1)] -join ' | '))) })
        }
    }
}

function Parse-Backlog([string]$Path, [string]$Root) {
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    $name = Split-Path (Split-Path $Path -Parent) -Leaf
    $tasks = [System.Collections.ArrayList]@()
    $contacts = @{}
    $projectStatus = $null
    $dealStage = $null
    $updatedNote = $null
    $profileSections = [System.Collections.ArrayList]@()

    $hdrProjectStatus = [string][char]0x0421 + [char]0x0442 + [char]0x0430 + [char]0x0442 + [char]0x0443 + [char]0x0441 + ' ' + [char]0x043f + [char]0x0440 + [char]0x043e + [char]0x0435 + [char]0x043a + [char]0x0442 + [char]0x0430
    $hdrBacklog = 'Backlog'
    $kStage = [string][char]0x042d + [char]0x0442 + [char]0x0430 + [char]0x043f
    $kStatus = [string][char]0x0421 + [char]0x0442 + [char]0x0430 + [char]0x0442 + [char]0x0443 + [char]0x0441
    $kPassport = [string][char]0x041f + [char]0x0430 + [char]0x0441 + [char]0x043f + [char]0x043e + [char]0x0440 + [char]0x0442

    $sectionTitle = ''
    $inBacklog = $false
    $currentProfile = $null
    $tableBuffer = [System.Collections.ArrayList]@()
    $inCode = $false
    $codeBuffer = [System.Collections.ArrayList]@()

    foreach ($rawLine in $lines) {
        $t = $rawLine.TrimEnd()

        if ($t -match '^>\s*(.+)$') {
            $updatedNote = $Matches[1].Trim()
            continue
        }

        if ($t -match '^##\s+(.+)$') {
            if ($currentProfile) {
                Flush-TableBuffer $currentProfile $tableBuffer
                if ($inCode -and $codeBuffer.Count -gt 0) {
                    [void]$currentProfile.blocks.Add(@{ kind = 'code'; text = ($codeBuffer -join "`n") })
                    $codeBuffer.Clear() | Out-Null
                    $inCode = $false
                }
            }

            $sectionTitle = $Matches[1].Trim()
            $inBacklog = ($sectionTitle -eq $hdrBacklog)
            $currentProfile = $null

            if ($sectionTitle -eq $hdrProjectStatus -or $sectionTitle -eq $hdrBacklog) {
                continue
            }

            $currentProfile = New-ProfileSection $sectionTitle
            [void]$profileSections.Add($currentProfile)
            continue
        }

        if ($t -match '^\s*---\s*$') { continue }

        if ($inBacklog) {
            $cells = Get-BacklogCells $t
            if ($cells -and $cells.Count -ge 5 -and $cells[0] -match '\w' -and $cells[0] -ne 'ID') {
                $assignee = ''
                $due = $null
                if ($cells.Count -ge 6) {
                    $due = $cells[4]
                    $assignee = $cells[5]
                } elseif ($cells.Count -ge 5) {
                    $assignee = $cells[4]
                }
                [void]$tasks.Add(@{
                    id = $cells[0]
                    title = $cells[1]
                    priority = $cells[2]
                    status = $cells[3]
                    due = $due
                    assignee = $assignee
                })
            }
            continue
        }

        if ($sectionTitle -eq $hdrProjectStatus) {
            $cells = Get-BacklogCells $t
            if ($cells -and $cells.Count -ge 2 -and $cells[0] -eq $kStatus) {
                $projectStatus = $cells[1]
            }
            continue
        }

        if (-not $currentProfile) { continue }

        if ($t -match '^```') {
            Flush-TableBuffer $currentProfile $tableBuffer
            if ($inCode) {
                [void]$currentProfile.blocks.Add(@{ kind = 'code'; text = ($codeBuffer -join "`n") })
                $codeBuffer.Clear() | Out-Null
                $inCode = $false
            } else {
                $inCode = $true
            }
            continue
        }

        if ($inCode) {
            [void]$codeBuffer.Add($rawLine)
            continue
        }

        if ($t -match '^###\s+(.+)$') {
            Flush-TableBuffer $currentProfile $tableBuffer
            Add-TextBlock $currentProfile ("### " + $Matches[1].Trim())
            continue
        }

        if ($t -match '^-\s+\[[ xX]\]\s+(.+)$') {
            Flush-TableBuffer $currentProfile $tableBuffer
            $last = if ($currentProfile.blocks.Count -gt 0) { $currentProfile.blocks[$currentProfile.blocks.Count - 1] } else { $null }
            if ($last -and $last.kind -eq 'checklist') {
                [void]$last.items.Add($Matches[1].Trim())
            } else {
                $items = [System.Collections.ArrayList]@()
                [void]$items.Add($Matches[1].Trim())
                [void]$currentProfile.blocks.Add(@{ kind = 'checklist'; items = $items })
            }
            continue
        }

        if ($t -match '^-\s+(.+)$') {
            Flush-TableBuffer $currentProfile $tableBuffer
            Add-TextBlock $currentProfile ("- " + $Matches[1].Trim())
            continue
        }

        $cells = Get-BacklogCells $t
        if ($cells) {
            [void]$tableBuffer.Add($cells)
            continue
        }

        Flush-TableBuffer $currentProfile $tableBuffer
        if (-not $t.Trim()) { continue }
        Add-TextBlock $currentProfile $t
    }

    if ($currentProfile) {
        Flush-TableBuffer $currentProfile $tableBuffer
    }

    foreach ($sec in $profileSections) {
        foreach ($block in $sec.blocks) {
            if ($block.kind -ne 'key_value') { continue }
            foreach ($row in $block.rows) {
                if ($row.Count -lt 2) { continue }
                if ($row[0] -eq $kStage) { $dealStage = $row[1] }
                if ($sec.title -match $kPassport) {
                    $contacts[$row[0]] = $row[1]
                }
            }
        }
    }

    $profile = @{
        updated_note = $updatedNote
        sections = @($profileSections | ForEach-Object {
            @{
                title = $_.title
                blocks = $_.blocks
            }
        })
    }

    return @{
        name = $name
        path = $Path.Substring($Root.Length).TrimStart('\', '/')
        domain = $null
        project_status = $projectStatus
        deal_stage = $dealStage
        contacts = $contacts
        tasks = $tasks
        profile = $profile
    }
}
