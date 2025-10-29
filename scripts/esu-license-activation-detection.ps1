<#
.SYNOPSIS
    Detects and reports the ESU (Extended Security Updates) license activation status for Windows 10 22H2 machines.

.DESCRIPTION
    This script checks whether a Windows 10 22H2 machine has an active ESU license by querying the SoftwareLicensingProduct WMI class.
    The script specifically looks for ESU activation IDs and verifies the license status. The result is stored in a NinjaRMM 
    custom field for centralized monitoring and reporting.

    The script performs the following operations:
    1. Verifies the machine is running Windows 10 22H2 (Build 19045)
    2. Queries the SoftwareLicensingProduct WMI class for ESU license information
    3. Checks for specific ESU activation IDs with active license status
    4. Stores the result in the 'cpvalEsuStatus' custom field in NinjaRMM

.PARAMETER None
    This script does not accept any parameters. It operates on the local machine where it's executed.

.EXAMPLE
    - 
    Executes the ESU license detection and stores the result in the custom field.

.OUTPUTS
    String. The script returns one of the following values:
    - "ESU Activated" - ESU license is active and properly configured
    - "ESU Not Activated" - No active ESU license found
    - "Not Windows 10 22H2" - Machine is not running the supported Windows version
    - "PowerShell Failure" - Error occurred while querying WMI data

.NOTES
    [script]
    name = "ESU License Activation Detection"
    description = "This script performs the checks for the ESU license activation detection and stores the info in the custom field 'cPVAL ESU Status'".
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

.LINK
    https://learn.microsoft.com/en-us/windows/whats-new/enable-extended-security-updates
    https://www.systemcenterdudes.com/deploy-windows-10-extended-security-update-key-with-intune-or-sccm/

.COMPONENT
    Windows Management Instrumentation (WMI)
    NinjaRMM
    License Management

.FUNCTIONALITY
    ESU License Detection
    Windows Version Validation
    Custom Field Management
#>

begin {
    #region Variables
    $supportedBuild = 19045
    $cfName = 'cpvalEsuStatus'
    $activationIds = @(
        'f520e45e-7413-4a34-a497-d2765967d094',
        '1043add5-23b1-4afb-9a0f-64343c8f3f8d',
        '83d49986-add3-41d7-ba33-87c7bfb5c0fb'
    )
    #endRegion
} process {
    #region OS Check
    $build = (Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction SilentlyContinue).buildNumber
    if ($build -ne $supportedBuild) {
        $value = 'Not Windows 10 22H2'
        return $value
    }
    #endRegion

    #region Check ESU License Status
    try {
        $esuLicense = Get-CimInstance -ClassName 'SoftwareLicensingProduct' -Filter 'partialproductkey is not null' -ErrorAction Stop |
            Where-Object {
                $_.LicenseStatus -eq 1 -and $activationIds -contains $_.Id
            }
    } catch {
        $value = 'PowerShell Failure'
        return $value
    }
    $value = if ( $esuLicense ) {
        'ESU Activated'
    } else {
        'ESU Not Activated'
    }
    return $value
    #endRegion
} end {
    #region set custom field
    Ninja-Property-Set -Name $cfName -Value $value
    #endRegion
}