<#
.SYNOPSIS
    Detects specified bloatware (potentially unwanted applications) installed on the local Windows machine.

.DESCRIPTION
    This script checks for the presence of bloatware applications as defined in the NinjaOne custom property 'cpvalBloatwareToRemove'.
    It performs the following steps:
        - Retrieves the list of bloatware to check from the NinjaOne custom property.
        - Cleans and parses the list into individual application names.
        - Prepares a working directory for logs and downloaded scripts.
        - Downloads a helper script from a remote repository to enumerate installed Appx and provisioned packages.
        - Executes the helper script to get a list of installed bloatware.
        - Validates the existence of log and error files to ensure the helper script executed successfully.
        - Compares the installed applications against the specified bloatware list.
        - Outputs the names of any found bloatware and exits with code 1 if any are found, or code 0 if none are found.
        - Logs all actions and errors for troubleshooting.

    The script is designed for use in automation and compliance scenarios, especially in environments managed by NinjaOne.
    It ensures only specified unwanted applications are flagged, and provides detailed logging for audit and troubleshooting purposes.

.EXAMPLE
    .\Find-Bloatware.ps1
    Checks for the presence of specified bloatware applications and reports the result.

.NOTES
    [script]
    name = "Find Bloatware"
    description = "Detects specified bloatware (potentially unwanted applications) installed on the local Windows machine."
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
$projectName = 'Remove-PUA'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
$ps1Log = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$errorLog = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
$baseUrl = 'https://contentrepo.net'
$scriptUrl = '{0}/repo/script/{1}.ps1' -f $baseUrl, $projectName
#endRegion

#region Ninja One Custom Property
$bloatwareToCheck = Ninja-Property-Get -Name 'cpvalBloatwareToRemove'
if (!($bloatwareToCheck)) {
    Write-Information 'Custom Property cpvalBloatwareToRemove is not set. Exiting script.'
    exit 0
}
$bloatwareList = $bloatwareToCheck -join "`n"
$bloatwareList = $bloatwareList -replace '\s+', ''
$bloatwareList = $bloatwareList -split ','
#endRegion

#region Working Directory
if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Information ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
        exit 0
    }
}
#endRegion

#region Download Script
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop -UseBasicParsing
} catch {
    if (!(Test-Path -Path $scriptPath)) {
        Write-Information ('Failed to download script from {0}. Reason: {1}' -f $scriptUrl, $($Error[0].Exception.Message))
        exit 0
    }
}
#endRegion

#region Execute Script
$installedBloatware = & $scriptPath -ListBloatware
#endRegion

#region Log Validation
if (!(Test-Path -Path $ps1Log)) {
    Write-Information ('Log file {0} not found. A Security application might have blocked the script''s execution.' -f $ps1Log)
    exit 0
}
if (Test-Path -Path $errorLog) {
    $errorContent = Get-Content -Path $errorLog -ErrorAction SilentlyContinue
    if ($errorContent) {
        Write-Information ('Error log {0} contains errors: {1}' -f $errorLog, ($errorContent | Out-String))
        exit 0
    }
}
#endRegion

#region Compare and return installed bloatware
$foundBloatware = @()
foreach ($bloatware in $bloatwareList) {
    if (($installedBloatware.AppxPackages -contains $bloatware) -or ($installedBloatware.ProvisionedPackages -contains $bloatware)) {
        $foundBloatware += $bloatware
    }
}

if ($foundBloatware) {
    $foundBloatware = $foundBloatware -join ', '
    Write-Information ('Found the following bloatware installed: {0}' -f $foundBloatware)
    exit 1
} else {
    Write-Information 'No specified bloatware found.'
    exit 0
}
#endRegion