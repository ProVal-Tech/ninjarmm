<#
.SYNOPSIS
The Windows 10 Extended Security Updates program provides critical security patches for up to three years beyond the official end of support date.

    [script]
    name = "Windows 10 Extended Security Update"
    description = "The Windows 10 Extended Security Updates program provides critical security patches for up to three years beyond the official end of support date."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "ESUKey"
    description = "Provide the ESU license key for activation of Windows 10 extended use."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.variables]]
    name = "ESUYear"
    description = "Select the license key year validation like 1, 2, or 3."
    type = "Drop-down"
    mandatory = false
    option_values = ["1", "2", "3"]
    top_option_is_default = false
#>

#requires -RunAsAdministrator
#requires -Version 5.1

# Begin block: Initialization and setup
Begin {
    #region Variables - Configure script environment and define constants
    # Suppress progress bars for cleaner output in automated environments
    $ProgressPreference = 'SilentlyContinue'
    # Disable confirmation prompts to allow unattended execution
    $ConfirmPreference = 'None'

    # NinjaRMM custom field names for configuration lookup
    $ESUKeyCustomField = 'cpvalESUKey'
    $ESUYearCustomField = 'cpvalESUYear'
    #endRegion

    #region Set Parameters - Configure Huntress deployment parameters
    $parameters = @{}  # Initialize parameter hash for installer

    # ESU Key Configuration (Highest Priority: Runtime Variable > Custom Field)
    $cfESUKey = Ninja-Property-Get $ESUKeyCustomField  # Get custom field value
    if (-not [string]::IsNullOrEmpty($env:ESUKey)) {
        $esu_key = $env:ESUKey  # Prefer runtime environment variable
    }
    elseif (-not [string]::IsNullOrEmpty($cfESUKey)) {
        $esu_key = $cfESUKey  # Fallback to NinjaRMM custom field
    }
    else {
        throw 'Error: ESU Key is missing. Please set the ESU Key in the custom field "cPVAL ESU Key" or as the runtime variable "ESU Key".'
    }

    # ESU Year Configuration (Runtime Variable > Custom Field)
    $cfESUYear = Ninja-Property-Get $ESUYearCustomField
    if (-not [string]::IsNullOrEmpty($env:ESUYear)) {
        $esu_year = $env:ESUYear
    }
    elseif (-not [string]::IsNullOrEmpty($cfESUYear)) {
        $esu_year = $cfESUYear
    }
    else {
        throw 'Error: ESU Year is missing. Please set the ESU Year in the custom field "cPVAL ESU Year" or as the runtime variable "ESU Year". Note: You can only use 1, 2, or 3 as Windows only allowed extensions for 3 years.'
    }
	
    # Validate ESU Year
    if ($esu_year -notin 1, 2, 3) {
        throw 'Error: Invalid ESU Year value. Only 1, 2, or 3 are allowed.'
    }
	
    # Build parameter hash for installer script
    $parameters.Add('esu_key', $esu_key)  # Mandatory account identifier
    $parameters.Add('esu_year', $esu_year)  # Organization identifier
}

# Process block: Execute the downloaded script with the specified parameters
Process {

    #Checking the compatibility of the Windows OS
    function Test-WindowsVersionAndCU {
        Write-Output 'Checking Windows version and cumulative update...'

        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $caption = $os.Caption
        $build = [int]$os.BuildNumber
        if ($caption -notmatch "Windows 10") {
            return "An error occurred: Not Compatible. Unsupported OS detected: $caption. This script is intended for Windows 10 only."
        }

        # Windows 10 22H2 has build number 19045
        if ($build -lt 19045) {
            return "An error occurred: Not Compatible. The Windows version is not 22H2 (Build 19045). Current build: $build"
        }

        # Check for KB5046613 or later
        $hotfixes = Get-HotFix | Where-Object { $_.HotFixID -match "^KB\d{7}$" }
        $requiredKB = 5046613

        $latestKB = $hotfixes |
        ForEach-Object {
            if ($_ -match "KB(\d{7})") {
                [int]$matches[1]
            }
        } |
        Sort-Object -Descending |
        Select-Object -First 1
        if ($latestKB -lt $requiredKB) {
            return "An error occurred: Not Compatible. Required cumulative update KB5046613 or later not found. Latest installed KB: KB$latestKB"
        }

        Write-Output 'Windows 10 version and update check passed.'
    }

    $compatibilityResult = Test-WindowsVersionAndCU
    if ($compatibilityResult -match "^An error occurred:") {
        return $compatibilityResult
    }

    # Activation IDs for each ESU year
    $ActivationIDs = @{
        1 = "f520e45e-7413-4a34-a497-d2765967d094"
        2 = "1043add5-23b1-4afb-9a0f-64343c8f3f8d"
        3 = "83d49986-add3-41d7-ba33-87c7bfb5c0fb"
    }

    $ActivationID = $ActivationIDs[$esu_year]

    function Invoke-SlmgrCommand {
        param (
            [string]$Arguments
        )
        $slmgrPath = "$env:SystemRoot\System32\slmgr.vbs"
        $cmd = "cscript.exe /nologo `"$slmgrPath`" $Arguments"
        try {
            $output = Invoke-Expression $cmd
            return $output
        }
        catch {
            return "An error occurred: slmgr.vbs failed with arguments '$Arguments'. Error: $_"
        }
    }
    try {
        Write-Output 'Installing ESU MAK key...'
        Invoke-SlmgrCommand "/ipk $esu_key"

        Write-Output "Activating ESU MAK key for Year $esu_year..."
        Invoke-SlmgrCommand "/ato $ActivationID"

        Write-Output 'Verifying activation status...'
        $dlvOutput = Invoke-SlmgrCommand "/dlv"
        if ($dlvOutput -match "Activation ID:\s+$ActivationID" -and $dlvOutput -match "License Status:\s+Licensed") {
            Write-Output "ESU license successfully activated for Year $esu_year."
        }
        else {
            Write-Output "Warning: Could not confirm ESU activation. Please manually verify the output below:"
            Write-Output $dlvOutput
        }

    }
    catch {
        return "An error occurred: $_"
    }

}

# End block: Final cleanup or additional actions (if needed)
End {}