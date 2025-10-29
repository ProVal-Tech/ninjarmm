#requires -Version 5

<#
.SYNOPSIS
    Applies Extended Security Updates (ESU) license for Windows 10 22H2 systems through NinjaRMM.

.DESCRIPTION
    This script applies Extended Security Updates (ESU) licenses to Windows 10 22H2 systems that have reached end-of-support.
    ESU provides critical security updates for Windows 10 systems beyond their normal support lifecycle.

    The script performs the following operations:
    - Validates system compatibility (Windows 10 22H2 Build 19045)
    - Checks for required cumulative update (KB5046613 or later)
    - Installs the ESU MAK (Multiple Activation Key)
    - Activates the ESU license for the specified year (1, 2, or 3)
    - Verifies the activation status

    ESU licenses are available for up to 3 years after Windows 10 reaches end-of-support, allowing organizations
    to continue receiving critical security updates while planning their migration to supported Windows versions.

.PARAMETER esuKey
    The ESU MAK (Multiple Activation Key) required for activation.
    This parameter can be provided via:
    - Runtime variable 'ESU Key'
    - NinjaRMM custom field 'cPVAL ESU Key'

    The ESU key is obtained from Microsoft Volume Licensing and is specific to your organization.
    If this parameter is missing, the script will throw an error with the message:
    "Error: ESU Key is missing. Please set the ESU Key in the custom field 'cPVAL ESU Key' or as the runtime variable 'ESU Key'."

.PARAMETER esuYear
    The ESU year for which the license should be activated.
    Valid values: 1, 2, or 3

    This parameter can be provided via:
    - Runtime variable 'ESU Year'
    - NinjaRMM custom field 'cPVAL ESU Year'

    ESU licenses are available for up to 3 years after Windows 10 end-of-support:
    - Year 1: First year of ESU coverage
    - Year 2: Second year of ESU coverage  
    - Year 3: Third year of ESU coverage

    If this parameter is missing, the script will throw an error with the message:
    "Error: ESU Year is missing. Please set the ESU Year in the custom field 'cPVAL ESU Year' or as the runtime variable 'ESU Year'. Note: You can only use 1, 2, or 3 as Windows only allowed extensions for 3 years."

    If an invalid value is provided, the script will throw:
    "Error: Invalid ESU Year value. Only 1, 2, or 3 are allowed."

.EXAMPLE
    -esuKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" -esuYear 1

    Applies ESU license for the first year using the specified MAK key.

.EXAMPLE
    -esuKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" -esuYear 2

    Applies ESU license for the second year using the specified MAK key.

.NOTES
    [script]
    name = "Windows 10 ESU License Upgrade"
    description = "Applies Extended Security Updates (ESU) license for Windows 10 22H2 systems through NinjaRMM. The Windows 10 Extended Security Updates program provides critical security patches for up to three years beyond the official end of support date."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "ESU Key"
    description = "Provide the ESU license key for activation of Windows 10 extended use."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.variables]]
    name = "ESU Year"
    description = "Provide the license key year validation in numeric form, like 1, 2, or 3."
    type = "Drop-down"
    mandatory = false
    option_values = ["1", "2", "3"]
    top_option_is_default = false

.LINK
    https://learn.microsoft.com/en-us/windows/whats-new/enable-extended-security-updates
    https://www.systemcenterdudes.com/deploy-windows-10-extended-security-update-key-with-intune-or-sccm/
#>

begin {
    #region Globals
    $ProgressPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    $InformationPreference = 'Continue'
    $WarningPreference = 'SilentlyContinue'
    #endRegion

    #region Ninja Variables
    $esuKeyCustomField = 'cpvalESUKey'
    $esuYearCustomField = 'cpvalESUYear'
    #endRegion

    #region Variables
    $requiredKB = 5046613
    $supportedBuild = 19045
    $activationIDs = @{
        1 = 'f520e45e-7413-4a34-a497-d2765967d094'
        2 = '1043add5-23b1-4afb-9a0f-64343c8f3f8d'
        3 = '83d49986-add3-41d7-ba33-87c7bfb5c0fb'
    }

    $activationID = $activationIDs[$esuYear]
    $slmgrPath = '{0}\System32\slmgr.vbs' -f $env:SystemRoot
    $acceptedEsuYearValues = @(1, 2, 3)
    #endRegion
} process {
    #region set parameters
    $cfESUKey = Ninja-Property-Get $esuKeyCustomField
    if (-not [string]::IsNullOrEmpty($env:esuKey)) {
        $esuKey = $env:esuKey
    } elseif (-not [string]::IsNullOrEmpty($cfESUKey)) {
        $esuKey = $cfESUKey
    } else {
        throw 'Error: ESU Key is missing. Please set the ESU Key in the custom field ''cPVAL ESU Key'' or as the runtime variable ''ESU Key''.'
    }

    $cfESUYearId = Ninja-Property-Get $esuYearCustomField
    $cfESUYearOptions = Ninja-Property-Options $esuYearCustomField
    if ($cfESUYearId) {
        $cfESUYear = $($($cfESUYearOptions -match [Regex]::Escape($cfESUYearId)).split('='))[1]
    }

    if (-not [string]::IsNullOrEmpty($env:esuYear)) {
        $esuYear = $env:esuYear
    } elseif (-not [string]::IsNullOrEmpty($cfESUYear)) {
        $esuYear = $cfESUYear
    } else {
        throw 'Error: ESU Year is missing. Please set the ESU Year in the custom field ''cPVAL ESU Year'' or as the runtime variable ''ESU Year''. Note: You can only use 1, 2, or 3 as Windows only allowed extensions for 3 years.'
    }

    if ($acceptedEsuYearValues -notcontains $esuYear) {
        throw 'Error: Invalid ESU Year value. Only 1, 2, or 3 are allowed.'
    }
    #endRegion

    #region Set TLS Policy
    $supportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
    if (($supportedTLSversions -contains 'Tls13') -and ($supportedTLSversions -contains 'Tls12')) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
    } elseif ($supportedTLSversions -contains 'Tls12') {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    } else {
        Write-Output 'TLS 1.2 and/or TLS 1.3 are not supported on this system. This download may fail!'
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Write-Output 'PowerShell 2 / .NET 2.0 doesn''t support TLS 1.2.'
        }
    }
    #endRegion

    #region Compatibility Check
    Write-Information 'Checking Windows version and cumulative update...'

    # Windows 10 22H2 has build number 19045
    $build = (Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction SilentlyContinue).buildNumber
    if ($build -ne $supportedBuild) {
        throw ('Error: Not Compatible. The Windows version is not 22H2 (Build 19045). Current build: {0}' -f $build)
    }

    # Check for KB5046613 or later
    $hotFixes = Get-HotFix | Where-Object { $_.HotFixID } | Select-Object @{
        Name = 'KBID'
        Expression = { $_.HotFixId -replace 'Kb', '' }
    }
    $latestKB = $hotFixes | Sort-Object -Property 'KBID' -Descending | Select-Object -First 1 -ExpandProperty 'KBID'
    if ($latestKB -lt $requiredKB) {
        throw ('Error: Not Compatible. Required cumulative update KB5046613 or later not found. Latest installed KB: KB{0}' -f $latestKB)
    }

    Write-Information 'Windows 10 version and update check passed.'
    #endRegion

    #region Set ESU Key
    Write-Information 'Installing ESU MAK key...'
    try {
        $argumentList = @(
            '/nologo',
            $slmgrPath,
            '/ipk',
            $esuKey
        )
        $procInfo = Start-Process -FilePath 'cscript.exe' -ArgumentList $argumentList -Wait -PassThru -NoNewWindow -ErrorAction Stop
    } catch {
        throw ('Error: Failed to install ESU Key. Process exited with the exit code {0}. Reason: {1}' -f $procInfo.ExitCode, $Error[0].Exception.Message)
    }
    #endRegion

    #region Activating ESU Key 
    Write-Information ('Activating ESU MAK key for Year {0}...' -f $esuYear)
    try {
        $argumentList = @(
            '/nologo',
            $slmgrPath,
            '/ato',
            $activationID
        )
        $procInfo = Start-Process -FilePath 'cscript.exe' -ArgumentList $argumentList -Wait -PassThru -NoNewWindow -ErrorAction Stop
    } catch {
        throw ('Error: Failed to activate ESU Key. Process exited with the exit code {0}. Reason: {1}' -f $procInfo.ExitCode, $Error[0].Exception.Message)
    }
    #endRegion

    #region Verification
    Write-Information 'Verifying activation status...'
    try {
        $argumentList = @(
            '/nologo',
            $slmgrPath,
            '/dlv'
        )
        $tempFile = '{0}\temp\slmgrDlv.txt' -f $env:SystemRoot
        $procInfo = Start-Process -FilePath 'cscript.exe' -ArgumentList $argumentList -Wait -PassThru -NoNewWindow -ErrorAction Stop -RedirectStandardOutput $tempFile
        $dlvOutput = Get-Content -Path $tempFile
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    } catch {
        throw ('Error: Failed to verify the activation status. Reason: {0}' -f $Error[0].Exception.Message)
    }

    $activationIDString = $dlvOutput -match 'Activation ID'
    $licenseStatusString = $dlvOutput -match 'License Status'

    if ($activationIDString -match [Regex]::Escape($activationID) -and $licenseStatusString -match 'Licensed') {
        return ('ESU license successfully activated for ''{0}'' year.' -f $esuYear)
    } else {
        return @"
Warning: Could not confirm ESU activation. Please manually verify the output below:
$($dlvOutput | Out-String)
"@
    }
    #endRegion
} end {}