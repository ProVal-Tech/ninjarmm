<#
.SYNOPSIS
    Compares the number of installed Cisco Secure Client modules with the number of selected modules in NinjaRMM custom fields.

.DESCRIPTION
    This script is designed to be executed as a pre-check script within a NinjaRMM compound condition. It performs a comparison
    between the number of Cisco Secure Client modules currently installed on the system and the number of modules selected in the
    NinjaRMM custom field configuration.

    The script performs the following operations:
    - Retrieves the list of installed Cisco Secure Client modules from the Windows registry
    - Retrieves the list of selected modules from the NinjaRMM custom field
    - Compares the count of installed modules with the count of selected modules
    - Returns an exit code based on the comparison result

    This script is typically used in a compound condition workflow where:
    - Exit code 0: The number of installed modules matches the number of selected modules (no action required)
    - Exit code 1: The counts differ, triggering the installation script ("Cisco Secure Client - Package Installation [Windows]")
    - Exit code 2: No modules are selected in the custom field (configuration error)

    When the script exits with code 1, it indicates that the installation script should be executed to bring the system
    into the desired state by installing the missing modules.

.NOTES
    name = "Cisco Secure Client - Module Comparison [Windows]"
    description = "Compares the number of installed Cisco Secure Client modules with the number of modules selected in the 'cPVAL Cisco Secure Client Modules' custom field. Used as a pre-check in compound conditions to determine if installation is required."
    categories = "ProVal"
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

.COMPONENT
    This script requires NinjaRMM-specific cmdlets (Ninja-Property-Get, Ninja-Property-Options) to retrieve custom field values.
    The script must be executed within a NinjaRMM automation context.

    CUSTOM FIELDS CONFIGURATION:
    The script reads configuration from the following NinjaRMM custom field:

    cPVAL Cisco Secure Client Modules (cpvalCiscoSecureClientModules)
        Type: Multi-select
        Mandatory: Yes
        Description: This field specifies which modules should be installed. The script compares the count of modules
                     selected in this field with the count of modules currently installed on the system. If "All" is
                     selected, the script compares against all available Windows modules.

.EXAMPLE
    This script is typically executed as part of a NinjaRMM compound condition workflow:

    Compound Condition Setup:
    1. Configure the "cPVAL Cisco Secure Client Modules" custom field with desired modules
    2. Set this script as the pre-check script in the compound condition
    3. Configure "Cisco Secure Client - Package Installation [Windows]" to run when this script exits with code 1
    4. The compound condition will automatically trigger installation when module counts differ

    Example workflow:
    - Pre-check: "Cisco Secure Client - Module Comparison [Windows]" (this script)
    - Condition: Exit code equals 1
    - Action: Execute "Cisco Secure Client - Package Installation [Windows]"

.EXITCODE
    0 - Success: The number of installed modules matches the number of selected modules. No installation required.
    1 - Mismatch: The number of installed modules differs from the number of selected modules. Installation script should be triggered.
    2 - Configuration Error: No modules have been selected in the custom field. Manual configuration required.

.INPUTS
    None. This script does not accept pipeline input. All configuration is retrieved from NinjaRMM custom fields.

.OUTPUTS
    The script writes informational messages to the console, including:
    - Count and list of installed modules
    - Count and list of selected modules
    - Comparison result and action recommendation

.LINK
    https://content.provaltech.com/docs/c79a196a-ec36-427e-9905-6610898432c9
#>

#region globals
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
#endRegion

#region variables
$modulesCustomField = 'cpvalCiscoSecureClientModules'
$softwareName = '^Cisco Secure Client'
$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
#endRegion

#region get number of installed modules
$installedApplications = Get-ChildItem $uninstallPaths -ErrorAction SilentlyContinue |
    Get-ItemProperty |
    Where-Object {
        $_.DisplayName -match $softwareName
    } | Sort-Object -Property DisplayName -Unique |
    Select-Object -ExpandProperty DisplayName
Write-Information -MessageData ('Number of installed modules: {0}' -f $installedApplications.Count) -InformationAction Continue
Write-Information -MessageData ('Installed modules:{0}{1}' -f [Environment]::NewLine, ($installedApplications | Out-String)) -InformationAction Continue
#endRegion

#region get selected modules
$selectedModulesGuid = Ninja-Property-Get $modulesCustomField
if ([string]::IsNullOrEmpty($selectedModulesGuid)) {
    Write-Information -MessageData 'No modules have been selected for installation. Please configure the ''cPVAL Cisco Secure Client Modules'' custom field with the desired modules and re-run the script.' -InformationAction Continue
    exit 2
}

$availableModules = Ninja-Property-Options $modulesCustomField
$selectedModulesGuid = $selectedModulesGuid -replace '\s', '' -split ','
$selectedModules = @()
$selectedModules += foreach ($selectedModuleGuid in $selectedModulesGuid) {
    $($($availableModules -match [Regex]::Escape($selectedModuleGuid)).split('='))[1]
}

if ($selectedModules -contains 'All') {
    $selectedModules = @(
        'Core-VPN',
        'Umbrella',
        'Diagnostic And Reporting Tool',
        'Network Access Manager (Windows Only)',
        'Network Visibility Module',
        'ISE Posture',
        'Start Before Login (Windows Only)',
        'VPN Posture (Windows Only)',
        'Zero Trust Access',
        'ThousandEyes Endpoint'
    )
}
Write-Information -MessageData ('Number of selected modules: {0}' -f $selectedModules.Count) -InformationAction Continue
Write-Information -MessageData ('Selected modules:{0}{1}' -f [Environment]::NewLine, ($selectedModules | Out-String)) -InformationAction Continue
#endRegion

#region compare installed and selected modules
if ($installedApplications.Count -ge $selectedModules.Count) {
    Write-Information 'The number of installed modules matches the number of selected modules. No installation action is required.' -InformationAction Continue
    exit 0
} else {
    Write-Information 'The number of installed modules does not match the number of selected modules. The installation script will be triggered to synchronize the module configuration.' -InformationAction Continue
    exit 1
}
#endRegion