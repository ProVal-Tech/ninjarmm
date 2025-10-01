<#
.SYNOPSIS
    Disables auto sleep in the current Windows power plan by setting "Sleep after" to Never for both AC and DC power.

.DESCRIPTION
    This script downloads and executes helper scripts to retrieve and modify Windows power plan settings.
    It checks the current sleep settings of the active power plan. If auto sleep is enabled (i.e., "Sleep after" is not set to Never),
    it sets "Sleep after" to Never for both AC and DC power using the downloaded Set-PowerPlan script.
    The script verifies the change and reports the result. Informational messages are output throughout the process.
    The script exits with code 0 if sleep is successfully disabled or already set to Never, and code 1 if an error occurs or the change fails.

.EXAMPLE
    .\Disable-AutoSleep.ps1
    Disables auto sleep on the current power plan and verifies the change.

.NOTES
    [script]
    name = "Disable Sleep"
    description = "Disables sleep in the current Windows power plan by setting 'Sleep after' to Never for both AC and DC power."
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
$getProjectName = 'Get-PowerPlan'
$setProjectName = 'Set-PowerPlan'
$workingDirectory = '{0}\_Automation\Script\PowerPlan' -f $env:ProgramData
$getScriptPath = '{0}\{1}.ps1' -f $workingDirectory, $getProjectName
$setScriptPath = '{0}\{1}.ps1' -f $workingDirectory, $setProjectName
$baseUrl = 'https://contentrepo.net'
$getScriptUrl = '{0}/repo/script/{1}.ps1' -f $baseUrl, $getProjectName
$setScriptUrl = '{0}/repo/script/{1}.ps1' -f $baseUrl, $setProjectName
$sleepSetting = @{ Subgroup = @{ 'Sleep' = @{ PowerSetting = @{ 'Sleep after' = @{ AC = 0; DC = 0 } } } } }
#endRegion

#region Working Directory
if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Information ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
        exit 1
    }
}
#endRegion

#region Download Get Script
try {
    Invoke-WebRequest -Uri $getScriptUrl -OutFile $getScriptPath -ErrorAction Stop -UseBasicParsing
} catch {
    if (!(Test-Path -Path $getScriptPath)) {
        Write-Information ('Failed to download script from {0}. Reason: {1}' -f $getScriptUrl, $($Error[0].Exception.Message))
        exit 1
    }
}
#endRegion

#region Download Set Script
try {
    Invoke-WebRequest -Uri $setScriptUrl -OutFile $setScriptPath -ErrorAction Stop -UseBasicParsing
} catch {
    if (!(Test-Path -Path $setScriptPath)) {
        Write-Information ('Failed to download script from {0}. Reason: {1}' -f $setScriptUrl, $($Error[0].Exception.Message))
        exit 1
    }
}
#endRegion

#region Execute Script
$powerPlanInfo = & $getScriptPath
#endRegion

#region Get Current Result
$activePlan = $powerPlanInfo | Where-Object { $_.Active }
if (!$activePlan) {
    Write-Information 'Failed to retrieve the active power plan.'
    exit 1
}

#region Disable Sleep
$sleepSettings = ($activePlan.Subgroups | Where-Object { $_.Name -eq 'Sleep' }).PowerSettings | Where-Object { $_.Name -eq 'Sleep after' }
if ($sleepSettings.CurrentACPowerSetting -ne '0 Seconds' -or $sleepSettings.CurrentDCPowerSetting -ne '0 Seconds') {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information 'Auto sleep is enabled.'
    Write-Information ('Sleep after (AC): {0}' -f $sleepSettings.CurrentACPowerSetting)
    Write-Information ('Sleep after (DC): {0}' -f $sleepSettings.CurrentDCPowerSetting)
    Write-Information 'Setting sleep after to Never on both AC and DC power...'

    & $setScriptPath -Name $activePlan.Name -Setting $sleepSetting

} else {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information 'Sleep after is set to Never on both AC and DC power.'
    exit 0
}
#endRegion

#region Verify Change
$powerPlanInfo = & $getScriptPath
$activePlan = $powerPlanInfo | Where-Object { $_.Active }
$sleepSettings = ($activePlan.Subgroups | Where-Object { $_.Name -eq 'Sleep' }).PowerSettings | Where-Object { $_.Name -eq 'Sleep after' }
if ($sleepSettings.CurrentACPowerSetting -ne '0 Seconds' -or $sleepSettings.CurrentDCPowerSetting -ne '0 Seconds') {
    Write-Information 'Failed to set sleep after to Never on both AC and DC power.'
    Write-Information ('Sleep after (AC): {0}' -f $sleepSettings.CurrentACPowerSetting)
    Write-Information ('Sleep after (DC): {0}' -f $sleepSettings.CurrentDCPowerSetting)
    Write-Information 'Failed to set sleep after to Never on both AC and DC power.'
    exit 1
} else {
    Write-Information 'Sleep after is set to Never on both AC and DC power.'
    exit 0
}
#endRegion