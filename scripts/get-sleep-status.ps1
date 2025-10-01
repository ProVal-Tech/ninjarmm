<#
.SYNOPSIS
    Checks the sleep settings of the current Windows power plan and reports if auto sleep is enabled.

.DESCRIPTION
    This script downloads and executes a helper script to retrieve detailed power plan information.
    It validates the existence of log files to ensure the script executed successfully and checks for errors.
    The script then analyzes the sleep settings of the active power plan, reporting whether auto sleep is enabled or set to never for both AC and DC power.
    Informational messages are output throughout the process, and the script exits with code 1 if auto sleep is enabled or errors are detected, and code 0 if sleep is set to never.

.EXAMPLE
    .\Get-SleepStatus.ps1
    Checks the current power plan's sleep settings and reports if auto sleep is enabled.

.NOTES
    [script]
    name = "Get Sleep Status"
    description = "Checks the sleep settings of the current Windows power plan and reports if auto sleep is enabled."
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
$projectName = 'Get-PowerPlan'
$workingDirectory = '{0}\_Automation\Script\PowerPlan' -f $env:ProgramData
$scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
$ps1Log = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$errorLog = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
$baseUrl = 'https://contentrepo.net'
$scriptUrl = '{0}/repo/script/{1}.ps1' -f $baseUrl, $projectName
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
$powerPlanInfo = & $scriptPath
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

#region Output Result
$activePlan = $powerPlanInfo | Where-Object { $_.Active }
$sleepSettings = ($activePlan.Subgroups | Where-Object { $_.Name -eq 'Sleep' }).PowerSettings | Where-Object { $_.Name -eq 'Sleep after' }
if ($sleepSettings.CurrentACPowerSetting -ne '0 Seconds' -or $sleepSettings.CurrentDCPowerSetting -ne '0 Seconds') {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information 'Auto sleep is enabled.'
    Write-Information ('Sleep after (AC): {0}' -f $sleepSettings.CurrentACPowerSetting)
    Write-Information ('Sleep after (DC): {0}' -f $sleepSettings.CurrentDCPowerSetting)
    exit 1
} else {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information 'Sleep after is set to Never on both AC and DC power.'
    exit 0
}
#endRegion