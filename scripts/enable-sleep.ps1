<#
.SYNOPSIS
    Enables auto sleep in the current Windows power plan by setting "Sleep after" to a specified timeout for both AC and DC power.

.DESCRIPTION
    This script downloads and executes helper scripts to retrieve and modify Windows power plan settings.
    It checks the current sleep settings of the active power plan. If auto sleep is not set to the specified timeout,
    it sets "Sleep after" to the desired value (default: 3600 seconds for AC, 900 seconds for DC) using the downloaded Set-PowerPlan script.
    The script verifies the change and reports the result. Informational messages are output throughout the process.
    The script exits with code 0 if sleep is successfully enabled or already set, and code 1 if an error occurs or the change fails.

.PARAMETER acTimeOutSeconds
    The timeout (in seconds) for sleep after on AC power. Default is 3600 seconds (1 hour).

.PARAMETER dcTimeOutSeconds
    The timeout (in seconds) for sleep after on DC power. Default is 900 seconds (15 minutes).

.EXAMPLE
    .\Enable-AutoSleep.ps1
    Enables auto sleep on the current power plan with default timeouts.

.EXAMPLE
    .\Enable-AutoSleep.ps1 -acTimeOutSeconds 1800 -dcTimeOutSeconds 600
    Enables auto sleep with custom timeouts for AC and DC power.

.NOTES
    [script]
    name = "Enable Sleep"
    description = "Enables sleep in the current Windows power plan by setting 'Sleep after' to a specified timeout for both AC and DC power."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "AC Time Out Seconds"
    description = "The timeout (in seconds) for sleep after on AC power."
    type = "Integer"
    mandatory = false
    default_value = 3600

    [[script.variables]]
    name = "DC Time Out Seconds"
    description = "The timeout (in seconds) for sleep after on DC power."
    type = "Integer"
    mandatory = false
    default_value = 900
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
$acTimeOut = if ([String]::IsNullOrEmpty($env:acTimeOutSeconds)) { 3600 } else { [int]$env:acTimeOutSeconds }
$dcTimeOut = if ([String]::IsNullOrEmpty($env:dcTimeOutSeconds)) { 900 } else { [int]$env:dcTimeOutSeconds }
$acTimeOutString = '{0} Seconds' -f $acTimeOut
$dcTimeOutString = '{0} Seconds' -f $dcTimeOut
$sleepSetting = @{ Subgroup = @{ 'Sleep' = @{ PowerSetting = @{ 'Sleep after' = @{ AC = $acTimeOut; DC = $dcTimeOut } } } } }
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
if ($sleepSettings.CurrentACPowerSetting -ne $acTimeOutString -or $sleepSettings.CurrentDCPowerSetting -ne $dcTimeOutString) {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information 'Auto sleep is not set.'
    Write-Information ('Sleep after (AC): {0}' -f $sleepSettings.CurrentACPowerSetting)
    Write-Information ('Sleep after (DC): {0}' -f $sleepSettings.CurrentDCPowerSetting)
    Write-Information ('Setting sleep after to {0} on AC and {1} on DC power...' -f $acTimeOutString, $dcTimeOutString)

    & $setScriptPath -Name $activePlan.Name -Setting $sleepSetting

} else {
    Write-Information ('Current Power Plan: {0}' -f $activePlan.Name)
    Write-Information ('Sleep after is set to {0} on AC and {1} on DC power...' -f $acTimeOutString, $dcTimeOutString)
    exit 0
}
#endRegion

#region Verify Change
$powerPlanInfo = & $getScriptPath
$activePlan = $powerPlanInfo | Where-Object { $_.Active }
$sleepSettings = ($activePlan.Subgroups | Where-Object { $_.Name -eq 'Sleep' }).PowerSettings | Where-Object { $_.Name -eq 'Sleep after' }
if ($sleepSettings.CurrentACPowerSetting -ne $acTimeOutString -or $sleepSettings.CurrentDCPowerSetting -ne $dcTimeOutString) {
    Write-Information ('Failed to set sleep after to {0} on AC and {1} on DC power...' -f $acTimeOutString, $dcTimeOutString)
    Write-Information ('Sleep after (AC): {0}' -f $sleepSettings.CurrentACPowerSetting)
    Write-Information ('Sleep after (DC): {0}' -f $sleepSettings.CurrentDCPowerSetting)
    exit 1
} else {
    Write-Information ('Sleep after is set to {0} on AC and {1} on DC power...' -f $acTimeOutString, $dcTimeOutString)
    exit 0
}
#endRegion