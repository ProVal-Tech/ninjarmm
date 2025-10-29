<#
.SYNOPSIS
    Enables SMB1 access auditing if disabled and scans event logs for recent SMB1 access attempts (Event IDs 1001, 3000) within the last hour. Returns exit codes for detection or script failure.

.NOTES
    [script]
    name = "SMB1 Access Audit and Detection"
    description = "Enables SMB1 access auditing if disabled and scans event logs for recent SMB1 access attempts (Event IDs 1001, 3000) within the last hour. Returns exit codes for detection or script failure."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

if (!( (Get-SmbServerConfiguration).AuditSmb1Access )) {
    try {
        Set-SmbServerConfiguration -AuditSmb1Access $true -Force -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Output "Failure Reason: $($Error[0].Exception.Message)"
        exit 2
    }
} else {
    function Get-SMB1AccessLog {
        param(
            [int[]]$Level,
            [int[]]$EventID,
            [int]$Hours
        )

        $filter = @{
            LogName = 'Microsoft-Windows-SMBServer*'
            Level = $Level
        }

        if ($EventID) {
            $filter.ID = $EventID
        }
        if ($Hours) {
            $filter.StartTime = (Get-Date).AddHours(-$Hours)
        }

        try {
            Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
        } catch {
            if ($Error[0].Exception.Message -match 'No events were found') {
                return 'No events were found that match the specified selection criteria'
            } else {
                Write-Output "Complete Failure: $($Error[0].Exception.Message)"
                exit 2
            }
        }
    }

    $detectedLogs = Get-SMB1AccessLog -Level 4 -EventID 1001, 3000 -Hours 1

    if ($detectedLogs) {
        $detectedLogs | Format-List
        exit 1
    } else {
        Write-Output 'No SMB1 access detected in the last hour'
        exit 0
    }
}
