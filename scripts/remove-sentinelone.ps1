<#
.SYNOPSIS
This script uninstalls the SentinelOne agent from a Windows system. It dynamically detects the installation directory of the SentinelOne agent and executes the uninstallation process.

.NOTES
    [script]
    name = "Remove SentinelOne"
    description = "This script uninstalls the SentinelOne agent from a Windows system. It dynamically detects the installation directory of the SentinelOne agent and executes the uninstallation process."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "PassPhrase"
    description = "Enter the PassPhrase to Uninstall the S1 Agent. This is required if Anti-Tamper protection is enabled."
    type = "String/Text"
    mandatory = false
    default_value = "<Leave it Blank>"
#>

#region parameters

$PassPhrase = ''
# Validate env variable if used
if ($env:passphrase -and ($env:passphrase).Length -ge 5 -and $env:passphrase -notlike '*PassPhrase*') {
    $PassPhrase = $env:passphrase
    Write-Output 'PassPhrase set from environment variable.'
}

if ($PassPhrase) {
    $Parameters = @{
        PassPhrase = "$PassPhrase"
    }
}
#endregion parameters

#region Setup - Variables
$ProjectName = 'Remove-SentinelOne'
[Net.ServicePointManager]::SecurityProtocol = [enum]::ToObject([Net.SecurityProtocolType], 3072)
$BaseURL = 'https://file.provaltech.com/repo'
$PS1URL = "$BaseURL/script/$ProjectName.ps1"
$WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
$PS1Path = "$WorkingDirectory\$ProjectName.ps1"
$WorkingPath = $WorkingDirectory
$LogPath = "$WorkingDirectory\$ProjectName-log.txt"
$ErrorLogPath = "$WorkingDirectory\$ProjectName-Error.txt"
#endregion

#region Setup - Folder Structure
New-Item -Path $WorkingDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$response = Invoke-WebRequest -Uri $PS1URL -UseBasicParsing
if (($response.StatusCode -ne 200) -and (!(Test-Path -Path $PS1Path))) {
    throw "No pre-downloaded script exists and the script '$PS1URL' failed to download. Exiting."
} elseif ($response.StatusCode -eq 200) {
    Remove-Item -Path $PS1Path -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllLines($PS1Path, $response.Content)
}
if (!(Test-Path -Path $PS1Path)) {
    throw 'An error occurred and the script was unable to be downloaded. Exiting.'
}
#endregion

#region Execution
if ($Parameters) {
    & $PS1Path @Parameters
} else {
    & $PS1Path
}
#endregion

#region log verification
if ( !(Test-Path $LogPath) ) {
    throw 'PowerShell Failure. A Security application seems to have restricted the execution of the PowerShell Script.'
}
if ( Test-Path $ErrorLogPath ) {
    $ErrorContent = ( Get-Content -Path $ErrorLogPath )
    throw $ErrorContent
}
$content = Get-Content -Path $LogPath
$logContent = $content[ $($($content.IndexOf($($content -match "$($ProjectName)$")[-1])) + 1)..$($Content.length - 1) ]
Write-Information ('Log Content: {0}' -f ($logContent | Out-String)) -InformationAction Continue
#endregion