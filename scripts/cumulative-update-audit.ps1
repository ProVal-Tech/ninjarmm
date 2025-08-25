<#
.SYNOPSIS
This Script validate the full version of the OS and compares it with Microsoft's database of Windows Cumulative Updates to identify which cumulative update the device has. The data is then formatted and stored in the Custom Field.
.NOTES
    [script]
    name = "Cumulative Update Audit"
    description = "This Script validate the full version of the OS and compares it with Microsoft's database of Windows Cumulative Updates to identify which cumulative update the device has. The data is then formatted and stored in the Custom Field."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "Threshold Days"
    description = "Enter the threshold days number to check if the CU Installed is older than the threshold Value. Default is 75."
    type = "[Integer]"
    mandatory = false
    default_value = "75"

    name = Custom Field Name
    description = "Enter the Name of Custom Field where you want the Audit Result. Leave Blank to store Output to 'cpvalCumulativeUpdateAuditStatus' Custom Field"
    type = "[String/Text]"
    mandatory = false
    default_value = ""
#>

#requires -RunAsAdministrator
#requires -Version 5

#region Global Variables
$ErrorActionPreference = 'silentlycontinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
#endRegion

#region CW RMM parameter
$ThresholdDays = "$env:thresholdDays"
$ThresholdDays = if ( -not ($ThresholdDays -match '^[0-9]{1,}$') ) { '75' } else { $ThresholdDays }
#endRegion

#region Setup - Variables
$ProjectName = 'Get-LatestInstalledCU'
$BaseURL = 'https://file.provaltech.com/repo'
$PS1URL = "$BaseURL/script/$ProjectName.ps1"
$WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
$PS1Path = "$WorkingDirectory\$ProjectName.ps1"
#endregion

#region Setup - Folder Structure
if ( !(Test-Path $WorkingDirectory ) ) {
    New-Item -Path $WorkingDirectory -ItemType Directory -Force | Out-Null
}

[Net.ServicePointManager]::SecurityProtocol = [enum]::ToObject([Net.SecurityProtocolType], 3072)
$response = Invoke-WebRequest -Uri $PS1URL -UseBasicParsing
if (($response.StatusCode -ne 200) -and (!(Test-Path -Path $PS1Path))) {
    throw "No pre-downloaded script exists and the script '$PS1URL' failed to download. Exiting."
    return
} elseif ($response.StatusCode -eq 200) {
    Remove-Item -Path $PS1Path -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllLines($PS1Path, $response.Content)
}
if (!(Test-Path -Path $PS1Path)) {
    throw 'An error occurred and the script was unable to be downloaded. Exiting.'
    return
}
#endregion

#region Execution
$CUInfo = & $ps1path
#endregion

if ( $Cuinfo -match 'Failed to gather build number|Unsupported Operating System' ) {
    throw "Failure Reason: $($Cuinfo)"
} else {
    $Today = Get-Date
    $FormattedDate = $Today.ToString('yyyy-MM-dd')
    $CompareFormat = [DateTime]$FormattedDate
    $ReleaseDate = $CUInfo.ReleaseDate
    $comparereleasedate = [DateTime]$ReleaseDate
    $Difference = New-TimeSpan -Start $comparereleasedate -End $CompareFormat
    $status = if ($Difference.Days -ge $ThresholdDays) { "Failed. CU Older than $ThresholdDays Days" } else { "Success. CU Newer than $ThresholdDays Days" }
    $Output = "$($status). || $($CUInfo.LastInstalledCU). || Version: $($CUInfo.OSBuild). || Date Audited: $FormattedDate"
    if ($env:customFieldName) {
        $CFName = "$env:customFieldName"
    } else {
        $CFName = 'cpvalCumulativeUpdateAuditStatus'
    }
    # Try to set the custom field value using the Set-NinjaProperty command
    try {
        Write-Output "Attempting to set Custom Field '$CFName'."
        Set-NinjaProperty -Name $CFName -Value $Output
        Write-Output "Successfully set Custom Field '$CFName'!"
    } catch {
        # If setting the custom field fails, display an error message and exit the script
        Write-Output "[Error] $($_.Exception.Message)"
    }
    Write-Output "`n $Output"
}

# Using exit codes for Monitoring Conditions
if ($Difference.Days -ge $ThresholdDays) {
    exit 1
} else {
    exit 0
}
