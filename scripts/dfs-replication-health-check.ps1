<#
.SYNOPSIS
    Checks for recent DFS Replication errors or warnings within the last hour and reports the current replication state to identify potential sync or replication issues.

.NOTES
    [script]
    name = "DFS Replication Health Check"
    description = "Checks for recent DFS Replication errors or warnings within the last hour and reports the current replication state to identify potential sync or replication issues."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

# Threshold in hours
$ThresholdHours = 1
$StartTime = (Get-Date).AddHours(-$ThresholdHours)

# Step 1: Check DFS Replication state
$DfsrState = Get-DfsrState 2>$null

# Step 2: Check DFS Replication event logs for errors/warnings
$EventErrors = Get-WinEvent -LogName 'DFS Replication' | Where-Object { $_.LevelDisplayName -in @('Error', 'Warning') -and $_.TimeCreated -ge $StartTime }

if ($EventErrors -or $DfsrState) {
    Write-Output 'DFS Replication issues detected'
    if ($DfsrState) {
        Write-Output 'Replication State:'
        $DfsrState | Group-Object UpdateState | Select-Object Name, Count | Format-Table -AutoSize
    }
    if ($EventErrors) {
        Write-Output 'Recent DFSR Errors/Warnings:'
        $EventErrors | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize
    }
    exit 1   # Trigger alert
} else {
    Write-Output "No DFS replication issues in the last $ThresholdHours hours"
    exit 0   # Healthy
}
