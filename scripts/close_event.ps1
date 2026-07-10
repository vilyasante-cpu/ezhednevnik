# Close calendar event/deadline in source markdown by stable key
param(
    [Parameter(Mandatory)][string]$Key,
    [string]$Outcome = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot 'calendar_lib.ps1')

$CursorRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$DailyFolder = [string][char]0x0415 + [char]0x0436 + [char]0x0435 + [char]0x0434 + [char]0x043D + [char]0x0435 + [char]0x0432 + [char]0x043D + [char]0x0438 + [char]0x043A
$CalendarName = [string][char]0x041A + [char]0x0410 + [char]0x041B + [char]0x0415 + [char]0x041D + [char]0x0414 + [char]0x0410 + [char]0x0420 + [char]0x042C + '.md'

if (-not $Key) {
    Write-Error "Key is required"
    exit 1
}

$calFiles = Get-ChildItem -Path $CursorRoot -Recurse -Filter $CalendarName |
    Where-Object { $_.FullName -notmatch $DailyFolder }

foreach ($file in $calFiles) {
    $domain = ($file.FullName.Substring($CursorRoot.Length).TrimStart('\', '/') -split '[\\/]')[0]
    $result = Close-EventInCalendarFile -Path $file.FullName -Key $Key -Domain $domain -Outcome $Outcome
    if ($result) {
        & (Join-Path $PSScriptRoot 'sync_data.ps1') | Out-Null
        $result | ConvertTo-Json -Compress
        exit 0
    }
}

Write-Error "Event not found for key: $Key"
exit 1
