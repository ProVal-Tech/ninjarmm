<#
.SYNOPSIS
    Enables Windows Firewall on all profiles on the local machine.

.DESCRIPTION
    This script checks all Windows Firewall profiles using Get-NetFirewallProfile.
    If any profile is disabled, it attempts to enable Windows Firewall on those profiles.
    Outputs informational messages about the process and exits with code 0 on success, 1 on failure.
    If all profiles are already enabled, it outputs a message and exits with code 0.
    Useful for compliance, automation, or troubleshooting scenarios where Windows Firewall must be enabled.

.EXAMPLE
    .\Enable-WindowsFirewall.ps1
    Enables Windows Firewall on all disabled profiles.

.NOTES
    [script]
    name = "Enable Windows Firewall"
    description = "Enables Windows Firewall on all profiles on the local machine."
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

# Enable Windows Firewall if it is disabled
$windowsFirewallStatus = Get-NetFirewallProfile -All -PolicyStore ActiveStore | Where-Object { -not $_.Enabled } | Select-Object -Property Name, Enabled, DefaultInboundAction, DefaultOutboundAction
if ($windowsFirewallStatus) {
    Write-Information ('Windows Firewall is disabled on the following profiles: {0}' -f ($windowsFirewallStatus | Out-String))
    Write-Information 'Enabling...'
    foreach ($firewallProfile in $windowsFirewallStatus) {
        try {
            Set-NetFirewallProfile -Profile $firewallProfile.Name -Enabled True -ErrorAction Stop
        } catch {
            Write-Information ('Failed to enable Windows Firewall: {0}' -f $Error[0].Exception.Message)
            exit 1
        }
    }
    Write-Information 'Windows Firewall has been enabled on all profiles.'
    exit 0
} else {
    Write-Information 'Windows Firewall is enabled on all profiles.'
    exit 0
}
#endRegion