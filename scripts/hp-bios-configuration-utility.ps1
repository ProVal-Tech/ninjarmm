<#
.SYNOPSIS
    Wrapper to download and execute the agnostic Initialize-HPBiosConfigUtility script to invoke the HP BIOS Configuration Utility (BCU) on HP workstations.

.DESCRIPTION
    This script downloads the agnostic script from:
      https://contentrepo.net/repo/script/Initialize-HPBiosConfigUtility.ps1
    and executes it, forwarding the NinjaRMM script variable Argument to the agnostic script.
    When run from NinjaRMM, the provided argument value is available in the process as $env:argument
    and will be passed to the agnostic script as its -Argument parameter. If no argument is supplied,
    the agnostic script will default to running HP BCU with '/get' to retrieve BIOS configuration.

.PARAMETER Argument
    Arguments to provide to the HP BIOS Configuration Utility (BCU) via the agnostic script.
    Examples:
      /get                              # read current configuration (default)
      /getvalue:"Fast Boot"             # read a single setting
      /setvalue:"Fast Boot","Enable"    # set a setting
      /help                             # show BCU help

    Note: When executed by NinjaRMM, set the NinjaRMM script variable named "Argument".
    The wrapper reads that value from $env:argument and forwards it to Initialize-HPBiosConfigUtility.ps1.

.EXAMPLE
    # From NinjaRMM: set Script Variable "Argument" to /getvalue:"Fast Boot"
    # The wrapper downloads and runs the agnostic script which runs BCU with that argument.

.NOTES
    [script]
    name = "HP Bios Configuration Utility"
    description = "Wrapper to download and execute the agnostic Initialize-HPBiosConfigUtility script to invoke the HP BIOS Configuration Utility (BCU) on HP workstations."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "Argument"
    description = "The argument to pass to the HP BIOS Configuration Utility (BCU) via the agnostic script."
    type = "String/Text"
    mandatory = false
    default_value = ""

.LINK
    - Agnostic script: https://contentrepo.net/repo/script/Initialize-HPBiosConfigUtility.ps1
    - HP Bios Configuration Utility CLI Reference: https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/BIOS_Configuration_Utility_User_Guide.pdf
#>
begin {
    #region Global
    $WarningPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    #endRegion

    #region Variables
    $projectName = 'Initialize-HPBiosConfigUtility'
    $workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
    $scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
    $logPath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
    $errorLogPath = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
    $baseUrl = 'https://contentrepo.net/repo'
    $scriptUrl = '{0}/script/{1}.ps1' -f $baseUrl, $projectName
    $exitCode = 0
    #endRegion
} process {
    #region manufacturer check
    if ((Get-CimInstance -ClassName Win32_ComputerSystem).manufacturer -notmatch 'HP|Hewlett') {
        Write-Information 'Unsupported device: This script is designed exclusively for HP workstations.' -InformationAction Continue
        $exitCode = 1
        return
    }
    #endRegion

    #region os check
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).Caption -notmatch 'Windows 10|Windows 11') {
        Write-Information 'Unsupported OS: This script is designed exclusively for Windows 10 and Windows 11.' -InformationAction Continue
        $exitCode = 1
        return
    }
    #endRegion

    #region working Directory
    if (!(Test-Path -Path $workingDirectory)) {
        try {
            New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Information ('Failed to Create {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message)) -InformationAction Continue
            $exitCode = 1
            return
        }
    }
    #endRegion

    #region Download Script
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    } catch {
        if (!(Test-Path -Path $scriptPath)) {
            Write-Information ('Failed to download the script from ''{0}'', and no local copy of the script exists on the machine. Reason: {1}' -f $scriptUrl, $($Error[0].Exception.Message)) -InformationAction Continue
            $exitCode = 1
            return
        }
    }
    #endRegion

    #region Execute script
    if ($env:argument) {
        & $scriptPath -Argument ('{0}' -f $env:argument)
    } else {
        & $scriptPath
    }
    #endRegion

    #region Log verification
    if (!(Test-Path -Path $logPath )) {
        Write-Information ('Failed to run the agnostic script ''{0}''. A security application seems to have interrupted the installation.' -f $scriptPath) -InformationAction Continue
        $exitCode = 1
    } elseif (Test-Path -Path $errorLogPath) {
        $content = Get-Content -Path $logPath
        $logContent = $content[ $($($content.IndexOf($($content -match "$($ProjectName)$")[-1])) + 1)..$($Content.length - 1) ]
        Write-Information ('Log Content: {0}' -f ($logContent | Out-String)) -InformationAction Continue
        $exitCode = 1
    }
    #endRegion
} end {
    exit $exitCode
}