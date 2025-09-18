<#
.SYNOPSIS
    Enables IPv6 protocol binding on all network adapters on the local Windows machine.

.DESCRIPTION
    This script enables the IPv6 protocol binding (ms_tcpip6) on all network adapters.
    Outputs informational messages about the process and exits with code 0 on success, 1 on failure.
    Useful for compliance, automation, or troubleshooting scenarios where IPv6 must be enabled.

.EXAMPLE
    .\Enable-IPv6.ps1
    Enables IPv6 on all network adapters.

.NOTES
    [script]
    name = "Enable IPv6"
    description = "Enables IPv6 protocol binding on all network adapters on the local Windows machine."
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

# Enable IPv6 on all network adapter
try {
    Enable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6 -ErrorAction Stop
} catch {
    Write-Information ('Failed to enable IPv6 on network adapters. Error: {0}' -f $_.Exception.Message)
    exit 1
}
Write-Information 'IPv6 has been successfully enabled on all network adapters.'
exit 0
#endRegion