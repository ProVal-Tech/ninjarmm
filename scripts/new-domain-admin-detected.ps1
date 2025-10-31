<#
.SYNOPSIS
Downloads and executes a script to identify new Domain Admin accounts, excluding specified accounts.

.DESCRIPTION
This script automates the process of retrieving the 'Get-NewDomainAdmin' script from a central repository,
executing it, and identifying new Domain Admin accounts in the environment. 
It supports the exclusion of specific accounts defined in a custom field ('cpvalExcludedDomainAdmins') 
and ensures the working directory exists before downloading the script.  

The script sets the appropriate TLS version (TLS 1.2 or 1.3) for secure downloads, handles errors 
during directory creation, script download, and execution, and outputs detailed information 
about any new Domain Admin accounts found. Exit codes are provided for integration with monitoring or automation systems:
  - Exit 1: New Domain Admin accounts detected
  - Exit 0: No new Domain Admin accounts found
  - Exit 2: Errors during directory creation, download, or script execution

.NOTES
    [script]
    name = "Domain Admin Account Lockouts"
    description = "This script monitors the Security log for recent account lockouts, checks if any Domain Admin accounts are affected, outputs detailed info about the locked accounts, and fails immediately if any Domain Admin is locked out."
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

#region Variables
$projectName = 'Get-NewDomainAdmin'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
$baseUrl = 'https://contentrepo.net/repo'
$scriptUrl = '{0}/script/{1}.ps1' -f $baseUrl, $projectName
$excludedAdminCustomFieldName = 'cpvalExcludedDomainAdmins'
$domainAdminMonitoringCustomField = 'cpvalNewDomainAdminMonitoring'
#endRegion

#region NinjaRMM custom fields
$domainAdminMonitoringId = Ninja-Property-Get -Name $domainAdminMonitoringCustomField
if ([string]::IsNullOrEmpty($domainAdminMonitoringId)) {
    Write-Information 'Domain Admin monitoring is not enabled on this device. Exiting script.'
    exit 0
}
$domainAdminMonitoringOptions = Ninja-Property-Options $domainAdminMonitoringId
if ($domainAdminMonitoringOptions) {
    $domainAdminMonitoringValue = $($($domainAdminMonitoringOptions -match [Regex]::Escape($domainAdminMonitoringId)).split('='))[1]
}
if ($domainAdminMonitoringValue -ne 'Enabled') {
    Write-Information 'Domain Admin monitoring is not enabled on this device. Exiting script.'
    exit 0
}

$excludedAdmin = Ninja-Property-Get -Name $excludedAdminCustomFieldName
$excludedAdminList = @()
if ($excludedAdmin) {
    $excludedAdminList = $excludedAdmin -split ','
}
#endRegion

#region Working Directory
if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Information ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
        exit 2
    }
}
#endRegion

#region set TlS policy
$supportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
if (($supportedTLSversions -contains 'Tls13') -and ($supportedTLSversions -contains 'Tls12')) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
} elseif ($supportedTLSversions -contains 'Tls12') {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
} else {
    Write-Information '[Warn] TLS 1.2 and/or TLS 1.3 are not supported on this system. This download may fail!'
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Information '[Warn] PowerShell 2 / .NET 2.0 doesn''t support TLS 1.2.'
    }
}

#region Download Get Script
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop -UseBasicParsing
} catch {
    if (!(Test-Path -Path $scriptPath)) {
        Write-Information ('Failed to download script from {0}. Reason: {1}' -f $scriptUrl, $($Error[0].Exception.Message))
        exit 2
    }
}
#endRegion

#region Execute Script
try {
    $newDomainAdmin = if ($excludedAdminList) {
        & $scriptPath -ErrorAction Stop | Where-Object { $excludedAdminList -notcontains $_.Name }
    } else {
        & $scriptPath -ErrorAction Stop
    }
} catch {
    Write-Information ('Failed to execute script from {0}. Reason: {1}' -f $scriptPath, $($Error[0].Exception.Message))
    exit 2
}
#endRegion

#region Output
if ($newDomainAdmin) {
    $newDomainAdmin | Format-List
    exit 1
} else {
    Write-Information 'No new domain admin found.'
    exit 0
}
#endRegion