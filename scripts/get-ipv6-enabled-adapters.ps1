<#
.SYNOPSIS
    Checks if IPv6 is enabled on any network adapter on the local Windows machine.

.DESCRIPTION
    This script queries all network adapters for the IPv6 protocol binding (ms_tcpip6).
    If any adapter has IPv6 enabled, it outputs the list of adapters and exits with code 1.
    If no adapters have IPv6 enabled, it outputs a message and exits with code 0.
    Useful for compliance checks or automation scenarios where IPv6 must be disabled.

.EXAMPLE
    .\Get-IPv6EnabledAdapters.ps1
    Checks all network adapters and reports if IPv6 is enabled.

.NOTES
    [script]
    name = "Get IPv6 Enabled Adapters"
    description = "Checks if IPv6 is enabled on any network adapter on the local Windows machine."
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
    exit 1
} else {
    Write-Information 'IPv6 is not enabled on any network adapters.'
    exit 0
}
#endRegion