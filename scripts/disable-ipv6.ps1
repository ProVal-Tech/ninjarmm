<#
.SYNOPSIS
    Disables IPv6 protocol binding on all network adapters on the local Windows machine. Disabling IPv6 may affect network connectivity in some environments.

.DESCRIPTION
    This script checks all network adapters for the IPv6 protocol binding (ms_tcpip6).
    If IPv6 is enabled on any adapter, it attempts to disable IPv6 on all adapters.
    Outputs informational messages about the process and exits with code 0 on success, 1 on failure.
    Useful for compliance, automation, or troubleshooting scenarios where IPv6 must be disabled.

.EXAMPLE
    .\Disable-IPv6.ps1
    Checks for IPv6 on all adapters and disables it if found.

.NOTES
    [script]
    name = "Disable IPv6"
    description = "Disables IPv6 protocol binding on all network adapters on the local Windows machine. Disabling IPv6 may affect network connectivity in some environments."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

#region Global Variables
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'
$InformationPreference = 'Continue'
#endRegion

# Check if IPv6 is enabled on any network adapter
$enabledIPV6 = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object { $_.Enabled }
if ($enabledIPV6) {
    Write-Information ('IPv6 is enabled on the following network adapters: {0}' -f ($enabledIPV6 | Out-String))
    Write-Information 'Disabling...'
    try {
        Disable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6 -ErrorAction Stop
    } catch {
        Write-Information ('Failed to disable IPv6 on network adapters. Error: {0}' -f $_.Exception.Message)
        exit 1
    }
    Write-Information 'IPv6 has been disabled on all network adapters.'
    exit 0
} else {
    Write-Information 'IPv6 is not enabled on any network adapters.'
    exit 0
}
#endRegion