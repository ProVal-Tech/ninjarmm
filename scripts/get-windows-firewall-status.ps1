<#
.SYNOPSIS
    Checks the status of Windows Firewall profiles on the local machine.

.DESCRIPTION
    This script queries all Windows Firewall profiles using Get-NetFirewallProfile.
    It reports which profiles have the firewall enabled, including their inbound and outbound default actions.
    If any profile is enabled, it outputs the details and exits with code 1.
    If all profiles are disabled, it outputs a message and exits with code 0.
    Useful for compliance checks, automation, or troubleshooting scenarios.

.EXAMPLE
    .\Get-WindowsFirewallStatus.ps1
    Checks all Windows Firewall profiles and reports their status.

.NOTES
    [script]
    name = "Get Windows Firewall Status"
    description = "Checks the status of Windows Firewall profiles on the local machine."
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

# Get Current Firewall Status
$windowsFirewallStatus = Get-NetFirewallProfile -All -PolicyStore ActiveStore | Where-Object { $_.Enabled } | Select-Object -Property Name, Enabled, DefaultInboundAction, DefaultOutboundAction
if ($windowsFirewallStatus) {
    Write-Information ('Windows Firewall is enabled on the following profiles: {0}' -f ($windowsFirewallStatus | Out-String))
    exit 1
} else {
    Write-Information 'Windows Firewall is disabled on all profiles.'
    exit 0
}
#endRegion