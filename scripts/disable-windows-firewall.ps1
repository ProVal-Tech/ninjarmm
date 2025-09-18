<#
.SYNOPSIS
    Disables Windows Firewall on all profiles on the local machine.

.DESCRIPTION
    This script checks all Windows Firewall profiles using Get-NetFirewallProfile.
    If any profile is enabled, it attempts to disable Windows Firewall on those profiles.
    Outputs informational messages about the process and exits with code 0 on success, 1 on failure.
    If all profiles are already disabled, it outputs a message and exits with code 0.
    Useful for compliance, automation, or troubleshooting scenarios where Windows Firewall must be disabled.

.EXAMPLE
    .\Disable-WindowsFirewall.ps1
    Disables Windows Firewall on all enabled profiles.

.NOTES
    [script]
    name = "Disable Windows Firewall"
    description = "Disables Windows Firewall on all profiles on the local machine."
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

# Disable Windows Firewall if it is enabled
$windowsFirewallStatus = Get-NetFirewallProfile -All -PolicyStore ActiveStore | Where-Object { $_.Enabled } | Select-Object -Property Name, Enabled, DefaultInboundAction, DefaultOutboundAction
if ($windowsFirewallStatus) {
    Write-Information ('Windows Firewall is enabled on the following profiles: {0}' -f ($windowsFirewallStatus | Out-String))
    Write-Information 'Disabling...'
    foreach ($firewallProfile in $windowsFirewallStatus) {
        try {
            Set-NetFirewallProfile -Profile $firewallProfile.Name -Enabled False -ErrorAction Stop
        } catch {
            Write-Information ('Failed to disable Windows Firewall: {0}' -f $Error[0].Exception.Message)
            exit 1
        }
    }
    Write-Information 'Windows Firewall has been disabled on all profiles.'
    exit 0
} else {
    Write-Information 'Windows Firewall is disabled on all profiles.'
    exit 0
}
#endRegion