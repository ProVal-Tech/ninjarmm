<#
.SYNOPSIS
    Detects and summarizes failed logon attempts (Event ID 4625) from the Windows Security event log within a specified time window.

.DESCRIPTION
    This script queries the Windows Security event log for failed logon attempts (Event ID 4625) within the past hour (default).
    It filters out logon types 4 (Batch) and 5 (Service), groups the remaining events, and provides a summary if the number of failed attempts exceeds a defined threshold.
    The output includes details such as username, domain, source IP, logon type, failure status, process information, and a reference table for logon types and failure reasons.

.PARAMETER threshold
    The threshold for the minimum number of failed logon events required to trigger the summary output. Default is 10.

.PARAMETER minutes
    The number of minutes in the past to search for failed logon events. Default is 60.

.NOTES
    [script]
    name = "Excessive Logon Attempts"
    description = "Detects and summarizes failed logon attempts (Event ID 4625) from the Windows Security event log within a specified time window.
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "Threshold"
    description = "The threshold for the minimum number of failed logon events required to trigger the summary output. Default is 10."
    type = "Integer"
    mandatory = true
    default_value = "10"

    [[script.variables]]
    name = "Minutes"
    description = "The number of minutes in the past to search for failed logon events. Default is 60."
    type = "Integer"
    mandatory = true
    default_value = "60"

.LINK
    - https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4625    
    - https://content.provaltech.com/docs/d9b666b4-e0b0-4736-94c1-06b430581bad/#troubleshooting
#>
Begin {
    $ErrorActionPreference = 'SilentlyContinue'
    $threshold = $env:threshold
    if (!$threshold -or $threshold -le 0) {
        $threshold = 10
    }
    $minutes = $env:minutes
    if (!$minutes -or $minutes -le 0) {
        $minutes = 60
    }
    $StartTime = (Get-Date).AddHours(-$minutes)

    $filter = @{
        LogName   = 'Security'
        ID        = 4625
        StartTime = $StartTime
    }
} Process {
    $events = Get-WinEvent -FilterHashtable $filter

    $filteredEvents = $events | Where-Object {
        $_.Message -notmatch 'Logon Type:\s+4' -and
        $_.Message -notmatch 'Logon Type:\s+5'
    }

    $total = ($filteredEvents | Measure-Object).Count

    if ($total -ge $th) {
        $groupedEvents = $filteredEvents |
            Where-Object { $_.Properties.Value -match '\S' } |
            Group-Object @{ Expression = { $_.Properties.Value } }, @{ Expression = { $_.Properties.Value } }

        $output = @()

        foreach ($group in $groupedEvents) {
            $ex = ([xml]$groupedEvents.Group[-1].ToXml()).Event
            $time = ([DateTime]$ex.System.TimeCreated.SystemTime).ToString('yyyy-MM-dd HH:mm:ss')
            $data = $ex.eventdata.data
            $e = [Ordered]@{}
            $data | ForEach-Object { $e[$_.Name] = $_.'#Text' }

            $procid = [Convert]::ToInt64($e.ProcessId, 16)
            $processStatus = if ($procid -gt 0 -and (Get-Process -Id $procid)) { 'Running' } else { 'Not Running' }

            $op = [PSCustomObject]@{
                UserName            = $e.TargetUserName
                UserSid             = $e.TargetUserSid
                Domain              = $e.TargetDomainName
                LogonType           = $e.LogonType
                WorkstationName     = $e.WorkstationName
                SourceIpAddress     = $e.IpAddress
                SourceIpPort        = $e.IpPort
                FailureStatus       = $e.Status
                FailureSubStatus    = $e.SubStatus
                callerProcessId     = $procid
                CallerProcessName   = $e.ProcessName
                CallerProcessStatus = $processStatus
                LogonProcess        = $e.LogonProcessName
                AuthenticationPackage = $e.AuthenticationPackageName
                TransmittedServices = $e.TransmittedServices
                NTLMPackageName     = $e.LmPackageName
                KeyLength           = $e.KeyLength
                Occurrences         = $group.Count
                MostRecentDetection = $time
            }
            $output += $op
        }
    } else {
        exit 0
    }
} end {
    if ($output) {
        Write-Output @"
$($total) failed logon event logs detected in the past $($hours) hour(s).
$($Output | Out-String)
Logon Type Reference Table:

2: Interactive
3: Network
4: Batch
5: Service
7: Unlock
8: NetworkCleartext
9: NewCredentials
10: RemoteInteractive
11: CachedInteractive

Failure Reason Reference Table:

0XC000005E: There are currently no logon servers available to service the logon request.
0xC0000064: User logon with misspelled or bad user account.
0xC000006A: User logon with misspelled or bad password for critical accounts or service accounts.
0XC000006D: This is either due to a bad username or authentication information for critical accounts or service accounts.
0xC000006F: User logon outside authorized hours.
0xC0000070: User logon from unauthorized workstation.
0xC0000072: User logon to account disabled by administrator.
0XC000015B: The user has not been granted the requested logon type (aka logon right) at this machine.
0XC0000192: An attempt was made to logon, but the Netlogon service was not started.
0xC0000193: User logon with expired account.
0XC0000413: Logon Failure: The machine you are logging onto is protected by an authentication firewall. The specified account is not allowed to authenticate to the machine.

Note: Compare FailureSubStatus (or FailureStatus if FailureSubStatus is not available) with the reference table mentioned above to identify the failure reason.

For more detailed information: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4625

To troubleshoot further, follow the troubleshooting section in the document: https://content.provaltech.com/docs/d9b666b4-e0b0-4736-94c1-06b430581bad/#troubleshooting
"@
    exit 1
    } else {
        exit 0
    }
}