<#
.SYNOPSIS
    Installs Cisco Secure Client modules on Windows systems using the Install-CiscoSecureClient agnostic PowerShell script.

.DESCRIPTION
    This script is designed to be executed from NinjaRMM automation and facilitates the installation of Cisco Secure Client modules
    by retrieving configuration values from NinjaRMM custom fields and passing them as parameters to the agnostic Install-CiscoSecureClient
    PowerShell script.

    The script performs the following operations:
    - Retrieves module selection and configuration values from NinjaRMM custom fields
    - Validates required custom field values based on selected modules
    - Downloads the Install-CiscoSecureClient agnostic script from ProVal's content repository
    - Constructs a parameter hash table based on custom field values
    - Executes the agnostic script with the appropriate parameters
    - Verifies script execution and displays log output

    This script acts as a wrapper that bridges NinjaRMM custom field configuration with the underlying agnostic installation script,
    making it easier to deploy Cisco Secure Client modules across multiple endpoints through RMM automation.

.NOTES
    name = "Cisco Secure Client - Package Installation [Windows]"
    description = "Attempts to install the modules selected in "cPVAL Cisco Secure Client Modules" using the installer specified in "cPVAL Cisco Secure Client Windows Source," provided as either a download URL or a local file path. Applicable for Windows systems."
    categories = "ProVal"
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

.COMPONENT
    This script requires NinjaRMM-specific cmdlets (Ninja-Property-Get, Ninja-Property-Options) to retrieve custom field values.
    The script must be executed within a NinjaRMM automation context.

    CUSTOM FIELDS CONFIGURATION:
    The script reads configuration from the following NinjaRMM custom fields:

    cPVAL Cisco Secure Client Modules (cpvalCiscoSecureClientModules)
        Type: Multi-select
        Mandatory: Yes
        Description: Use this field to specify which modules should be installed. If you select "All," all available modules
                     will be installed regardless of other selections. Note: If the Umbrella module is selected, you must
                     configure UserID, Fingerprint, and OrgID. Choosing "All" will override individual selections and install
                     every module.
        Available Options:
            - All
            - Core-VPN
            - Umbrella
            - Diagnostic And Reporting Tool
            - Network Visibility Module
            - ISE Posture
            - ThousandEyes Endpoint
            - Zero Trust Access
            - Start Before Login (Windows Only)
            - Network Access Manager (Windows Only)
            - VPN Posture (Windows Only)
            - Duo (Mac Only)
            - Fireamp (Mac Only)
            - Secure Firewall Posture (Mac Only)

    cPVAL Cisco Secure Client Windows Source (cpvalCiscoSecureClientWindowsSource)
        Type: Text/String
        Mandatory: Yes
        Description: Provide the download URL or local file path for the .zip file used to install Cisco Secure Client modules
                     on Windows machines. Accepts HTTP/HTTPS URLs or local file paths (e.g., C:\Path\To\File.zip).

    cPVAL Cisco Secure Client Umbrella UserID (cpvalCiscoSecureClientUmbrellaUserid)
        Type: Text/String
        Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
        Description: Provide the Umbrella UserID associated with your organization. This field is required if you choose "All"
                     or select the Umbrella module for installation.

    cPVAL Cisco Secure Client Umbrella Fingerprint (cpvalCiscoSecureClientUmbrellaFingerprint)
        Type: Text/String
        Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
        Description: Provide the Umbrella Fingerprint associated with your organization. This field is required if you choose
                     "All" or select the Umbrella module for installation.

    cPVAL Cisco Secure Client Umbrella OrgID (cpvalCiscoSecureClientUmbrellaOrgid)
        Type: Text/String
        Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
        Description: Provide the Umbrella OrgID associated with your organization. This field is required if you choose "All"
                     or select the Umbrella module for installation.

    cPVAL Cisco Secure Client Windows Show VPN (cpvalCiscoSecureClientWindowsShowVpn)
        Type: Checkbox/Boolean
        Mandatory: No
        Description: Check this box if you want the Core-VPN module to appear in the system tray icon. By default, the solution
                     does not display Core-VPN in the tray.

    cPVAL Cisco Secure Client Windows ARP (cpvalCiscoSecureClientWindowsArp)
        Type: Checkbox/Boolean
        Mandatory: No
        Description: Check this box if you want Cisco Secure Client modules to be hidden from the Add/Remove Programs section
                     in Windows. This setting applies only to Windows systems.

    cPVAL Cisco Secure Client Windows Lockdown (cpvalCiscoSecureClientWindowsLockdown)
        Type: Checkbox/Boolean
        Mandatory: No
        Description: Check this box to lock Cisco Secure Client services and prevent any modifications. This lockdown applies
                     to all users, including administrators. This setting is supported only on Windows systems.

.EXAMPLE
    This script is typically executed as a NinjaRMM automation. Ensure all required custom fields are configured before execution.

    Example workflow:
    1. Configure "cPVAL Cisco Secure Client Modules" custom field with desired modules (e.g., "Core-VPN", "Umbrella")
    2. Configure "cPVAL Cisco Secure Client Windows Source" with the installer .zip file URL or path
    3. If Umbrella is selected, configure UserID, Fingerprint, and OrgID custom fields
    4. Optionally configure Show VPN, ARP, and Lockdown settings
    5. Execute the automation

.INPUTS
    None. This script does not accept pipeline input. All configuration is retrieved from NinjaRMM custom fields.

.OUTPUTS
    The script writes log information to the console and creates log files in:
    - $env:ProgramData\_Automation\Script\Install-CiscoSecureClient\Install-CiscoSecureClient-log.txt
    - $env:ProgramData\_Automation\Script\Install-CiscoSecureClient\Install-CiscoSecureClient-error.txt

.LINK
    https://content.provaltech.com/docs/ff9b5cb7-981d-4a25-b584-5fb486b92308
#>

#region globals
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
#endRegion

#region variables
$projectName = 'Install-CiscoSecureClient'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
$logPath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$errorLogPath = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
$baseUrl = 'https://contentrepo.net/repo'
$scriptUrl = '{0}/script/{1}.ps1' -f $baseUrl, $projectName
#endRegion

#region ninja rmm variables
$modulesCustomField = 'cpvalCiscoSecureClientModules'
$sourceCustomField = 'cpvalCiscoSecureClientWindowsSource'
$userIdCustomField = 'cpvalCiscoSecureClientUmbrellaUserid'
$fingerprintCustomField = 'cpvalCiscoSecureClientUmbrellaFingerprint'
$orgIdCustomField = 'cpvalCiscoSecureClientUmbrellaOrgid'
$showVpnCustomField = 'cpvalCiscoSecureClientWindowsShowVpn'
$windowsArpCustomField = 'cpvalCiscoSecureClientWindowsArp'
$windowsLockdownCustomField = 'cpvalCiscoSecureClientWindowsLockdown'
#endRegion

#region fetch custom field values
$selectedModulesGuid = Ninja-Property-Get $modulesCustomField
if ([string]::IsNullOrEmpty($selectedModulesGuid)) {
    throw 'No modules have been selected for installation. Please configure the ''cPVAL Cisco Secure Client Modules'' custom field with the desired modules and re-run the script.'
}

$availableModules = Ninja-Property-Options $modulesCustomField
$selectedModulesGuid = $selectedModulesGuid -replace '\s', '' -split ','
$selectedModules = @()
$selectedModules += foreach ($selectedModuleGuid in $selectedModulesGuid) {
    $($($availableModules -match [Regex]::Escape($selectedModuleGuid)).split('='))[1]
}

$source = Ninja-Property-Get $sourceCustomField
if ([string]::IsNullOrEmpty($source)) {
    throw 'The installation source has not been configured. Please provide a valid URL or local file path to the Cisco Secure Client .zip installer in the ''cPVAL Cisco Secure Client Windows Source'' custom field and re-run the script.'
} if (-not ($source -match '^([A-z]|https?):')) {
    throw 'The installation source format is invalid. Please provide a valid URL (http:// or https://) or local file path (drive letter format) to the Cisco Secure Client .zip installer in the ''cPVAL Cisco Secure Client Windows Source'' custom field and re-run the script.'
}

$userId = Ninja-Property-Get $userIdCustomField
if ($selectedModules -match '^(Umbrella|All)$' -and [string]::IsNullOrEmpty($userId)) {
    throw 'The Umbrella UserID is required but has not been configured. Please enter the UserID value in the ''cPVAL Cisco Secure Client Umbrella UserID'' custom field and re-run the script. This field is mandatory when the ''All'' or ''Umbrella'' module is selected.'
}

$fingerprint = Ninja-Property-Get $fingerprintCustomField
if ($selectedModules -match '^(Umbrella|All)$' -and [string]::IsNullOrEmpty($fingerprint)) {
    throw 'The Umbrella Fingerprint is required but has not been configured. Please enter the Fingerprint value in the ''cPVAL Cisco Secure Client Umbrella Fingerprint'' custom field and re-run the script. This field is mandatory when the ''All'' or ''Umbrella'' module is selected.'
}

$orgId = Ninja-Property-Get $orgIdCustomField
if ($selectedModules -match '^(Umbrella|All)$' -and [string]::IsNullOrEmpty($orgId)) {
    throw 'The Umbrella OrgID is required but has not been configured. Please enter the OrgID value in the ''cPVAL Cisco Secure Client Umbrella OrgID'' custom field and re-run the script. This field is mandatory when the ''All'' or ''Umbrella'' module is selected.'
}

$showVpn = Ninja-Property-Get $showVpnCustomField
$arp = Ninja-Property-Get $windowsArpCustomField
$lockdown = Ninja-Property-Get $windowsLockdownCustomField
#endRegion

#region RMM parameters hash table
$parameters = @{
    Source = $source
}

if ($selectedModules -contains 'All') {
    $parameters.Add('All', $true)
} else {
    if ($selectedModules -contains 'Core-VPN') {
        $parameters.Add('Core', $true)
    }
    if ($selectedModules -contains 'Umbrella') {
        $parameters.Add('Umbrella', $true)
    }
    if ($selectedModules -contains 'Diagnostic And Reporting Tool') {
        $parameters.Add('Dart', $true)
    }
    if ($selectedModules -contains 'Network Access Manager (Windows Only)') {
        $parameters.Add('Nam', $true)
    }
    if ($selectedModules -contains 'Network Visibility Module') {
        $parameters.Add('Nvm', $true)
    }
    if ($selectedModules -contains 'ISE Posture') {
        $parameters.Add('IsePosture', $true)
    }
    if ($selectedModules -contains 'Start Before Login (Windows Only)') {
        $parameters.Add('Sbl', $true)
    }
    if ($selectedModules -contains 'VPN Posture (Windows Only)') {
        $parameters.Add('Posture', $true)
    }
    if ($selectedModules -contains 'Zero Trust Access') {
        $parameters.Add('Zta', $true)
    }
    if ($selectedModules -contains 'ThousandEyes Endpoint') {
        $parameters.Add('ThousandEyes', $true)
    }
}

if ($selectedModules -contains 'Umbrella' -or $selectedModules -contains 'All') {
    $parameters.Add('UserID', $userId)
}

if ($selectedModules -contains 'Umbrella' -or $selectedModules -contains 'All') {
    $parameters.Add('Fingerprint', $fingerprint)
}

if ($selectedModules -contains 'Umbrella' -or $selectedModules -contains 'All') {
    $parameters.Add('OrgId', $orgId)
}

if ($showVpn -eq 1) {
    $parameters.Add('ShowVPN', $true)
}

if ($arp -eq 1) {
    $parameters.Add('ARP', $true)
}

if ($lockdown -eq 1) {
    $parameters.Add('Lockdown', $true)
}
#endRegion

#region working Directory
if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        throw ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $Error[0].Exception.Message)
    }
}

$acl = Get-Acl -Path $workingDirectory
$hasFullControl = $acl.Access | Where-Object {
    $_.IdentityReference -match 'Everyone' -and $_.FileSystemRights -match 'FullControl'
}
if (-not $hasFullControl) {
    $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule(
        'Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    )
    $acl.AddAccessRule($accessRule)
    Set-Acl -Path $workingDirectory -AclObject $acl -ErrorAction SilentlyContinue
}
#endRegion

#region set tls policy
$supportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
if (($supportedTLSversions -contains 'Tls13') -and ($supportedTLSversions -contains 'Tls12')) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
} elseif ($supportedTLSversions -contains 'Tls12') {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
} else {
    Write-Information 'TLS 1.2 and/or TLS 1.3 are not supported on this system. This download may fail!' -InformationAction Continue
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Information 'PowerShell 2 / .NET 2.0 doesn''t support TLS 1.2.' -InformationAction Continue
    }
}
#endRegion

#region download script
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
} catch {
    if (!(Test-Path -Path $scriptPath)) {
        throw ('Failed to download the script from ''{0}'', and no local copy of the script exists on the machine. Reason: {1}' -f $scriptUrl, $Error[0].Exception.Message)
    }
}
#endRegion

#region execute script
if ($parameters) {
    & $scriptPath @parameters
} else {
    & $scriptPath
}
#endRegion

#region log verification
if (!(Test-Path -Path $logPath )) {
    throw ('Failed to run the agnostic script ''{0}''. A security application seems to have interrupted the installation.' -f $scriptPath)
} else {
    $content = Get-Content -Path $logPath
    $logContent = $content[ $($($content.IndexOf($($content -match "$($projectName)$")[-1])) + 1)..$($content.length - 1) ]
    Write-Information ('Log Content: {0}' -f ($logContent | Out-String)) -InformationAction Continue
}

if ((Test-Path -Path $errorLogPath)) {
    $errorLogContent = Get-Content -Path $errorLogPath -ErrorAction SilentlyContinue
    throw ('Error log Content: {0}' -f ($errorLogContent | Out-String -ErrorAction SilentlyContinue))
}
#endRegion