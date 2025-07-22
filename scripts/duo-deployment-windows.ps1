#requires -RunAsAdministrator
#requires -Version 5.1

<#
.SYNOPSIS
Automates the installation or update of Duo Authentication for Windows Logon.

.NOTES
    [script]
    name = "Duo Deployment - Windows"
    description = "This script will install or update DUO if the currently installed instance is older than the latest released version. It matches the hash of the installer from the official website before deploying it."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
    
- Requires PowerShell 5.1 or later.
- Must be run with administrative privileges.
- Designed for use in NinjaRMM.
- Logs installation details to a specified log file for troubleshooting purposes.

.DESCRIPTION
This script is designed to automate the installation or update process for Duo Authentication for Windows Logon. It performs the following steps:

1. **Environment Preparation**:
   - Ensures the script is run with administrative privileges.
   - Configures script environment variables and constants, such as working directories, download URLs, and log file paths.
   - Enforces TLS 1.2 for secure network communications.
   - Prepares a clean working directory by removing any existing files and ensuring proper permissions.

2. **Configuration Retrieval**:
   - Retrieves Duo configuration values (e.g., IKEY, SKEY, HOST) from NinjaRMM custom fields.
   - Validates the presence of required configuration values and throws errors if any are missing.
   - Configures optional Duo settings such as AutoPush, FailOpen, RdpOnly, SmartCard, and UAC-related options based on custom fields.

3. **Version Comparison**:
   - Fetches the latest version of the Duo installer from the Duo Security website.
   - Compares the installed version (if any) with the latest version to determine if an update is required.

4. **Installer Download and Validation**:
   - Downloads the latest Duo installer from the official Duo Security URL.
   - Verifies the integrity of the downloaded installer by comparing its SHA256 hash with the vendor-provided hash.

5. **Installation**:
   - Constructs the installation arguments dynamically based on the retrieved configuration values.
   - Unblocks the downloaded installer file to ensure it can be executed.
   - Executes the installer with the constructed arguments in silent mode and waits for the process to complete.

6. **Validation**:
   - Waits for 30 seconds after installation to allow the system to register the changes.
   - Checks the installed version of Duo Authentication for Windows Logon in the system registry.
   - Confirms if the installed version matches the latest version and provides appropriate success or error messages.

7. **Cleanup**:
   - Removes the working directory and any temporary files created during the script execution.

.PARAMETER None
This script does not accept any parameters. All configuration values are retrieved from NinjaRMM custom fields.

.EXAMPLE
.\Install-DUONinjaRMM.ps1
Runs the script to install or update Duo Authentication for Windows Logon using the configuration values provided in the NinjaRMM custom fields.
#>

Begin {
    #region Ninja Variables
    $productType = (Get-CimInstance -ClassName WIn32_OperatingSystem -ErrorAction SilentlyContinue).ProductType

    #Duo IKEY
    $cfDuoIKey = Ninja-Property-Get 'cpvalDuoIkey'
    if (-not [string]::IsNullOrEmpty($cfDuoIKey)) {
        $iKey = $cfDuoIKey  # NinjaRMM custom field
    } else {
        throw 'Error: DUO integration key is missing. Please set the DUO integration Key in the custom field ''cPVAL DUO IKEY''.'
    }

    #Duo SKEY
    $cfDuoSKey = Ninja-Property-Get 'cpvalDuoSkey'
    if (-not [string]::IsNullOrEmpty($cfDuoSKey)) {
        $sKey = $cfDuoSKey  # NinjaRMM custom field
    } else {
        throw 'Error: DUO secret key is missing. Please set the DUO secret Key in the custom field ''cPVAL DUO SKEY''.'
    }

    #Duo HKEY
    $cfDuoHKey = Ninja-Property-Get 'cpvalDuoHkey'
    if (-not [string]::IsNullOrEmpty($cfDuoHKey)) {
        $hKey = $cfDuoHKey  # NinjaRMM custom field
    } else {
        throw 'Error: DUO API hostname is missing. Please set the DUO API hostname Key in the custom field ''cPVAL DUO HKEY''.'
    }

    #Duo AutoPush
    $cfDuoAutoPushID = Ninja-Property-Get 'cpvalDuoAutopush'
    $cfDuoAutoPushOption = Ninja-Property-Options 'cpvalDuoAutopush'
    if ($cfDuoAutoPushID) {
      $cfDuoAutoPush = $($($cfDuoAutoPushOption -match [Regex]::Escape($cfDuoAutoPushID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoAutoPush)) {
        $autoPush = $cfDuoAutoPush  # NinjaRMM custom field
    }

    $autoPush = Switch ($autoPush) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'All' { '1' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo FailOpen
    $cfDuoFailOpenID = Ninja-Property-Get 'cpvalDuoFailopen'
    $cfDuoFailOpenOption = Ninja-Property-Options 'cpvalDuoFailopen'
    if ($cfDuoFailOpenID) {
      $cfDuoFailOpen = $($($cfDuoFailOpenOption -match [Regex]::Escape($cfDuoFailOpenID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoFailopen)) {
        $failOpen = $cfDuoFailopen  # NinjaRMM custom field
    }
    $failOpen = Switch ($failOpen) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'All' { '1' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo RdpOnly
    $cfDuoRdponlyID = Ninja-Property-Get 'cpvalDuoRdponly'
    $cfDuoRdponlyOption = Ninja-Property-Options 'cpvalDuoRdponly'
    if ($cfDuoRdponlyID) {
      $cfDuoRdponly = $($($cfDuoRdponlyOption -match [Regex]::Escape($cfDuoRdponlyID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoRdponly)) {
        $rdpOnly = $cfDuoRdponly  # NinjaRMM custom field
    }
    $rdpOnly = Switch ($rdpOnly) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo SmartCard
    $cfDuoSmartCardId = Ninja-Property-Get 'cpvalDuoSmartcard'
    $cfDuoSmartCardOption = Ninja-Property-Options 'cpvalDuoSmartcard'
    if ($cfDuoSmartCardId) {
      $cfDuoSmartCard = $($($cfDuoSmartCardOption -match [Regex]::Escape($cfDuoSmartCardID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoSmartCard)) {
        $smartCard = $cfDuoSmartCard  # NinjaRMM custom field
    }
    $smartCard = Switch ($smartCard) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'All' { '1' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo WrapSmartCard
    $cfDuoWrapsmartCardID = Ninja-Property-Get 'cpvalDuoWrapsmartcard'
    $cfDuoWrapsmartCardOption = Ninja-Property-Options 'cpvalDuoWrapsmartcard'
    if ($cfDuoWrapsmartCardID){
      $cfDuoWrapsmartCard = $($($cfDuoWrapsmartCardOption -match [Regex]::Escape($cfDuoWrapsmartCardID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoWrapsmartCard)) {
        $wrapSmartCard = $cfDuoWrapsmartCard  # NinjaRMM custom field
    }
    $wrapSmartCard = Switch ($wrapSmartCard) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo EnableOffline
    $cfDuoEnableofflineID = Ninja-Property-Get 'cpvalDuoEnableoffline'
    $cfDuoEnableofflineOption = Ninja-Property-Options 'cpvalDuoEnableoffline'
    if ($cfDuoEnableofflineID) {
     $cfDuoEnableoffline = $($($cfDuoEnableofflineOption -match [Regex]::Escape($cfDuoEnableofflineID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoEnableoffline)) {
        $enableOffline = $cfDuoEnableoffline  # NinjaRMM custom field
    }
    $enableOffline = Switch ($enableOffline) {
        '0' { '0' }
        '1' { '1' }
        'Disabled' { '0' }
        'Windows' { '1' }
        'Windows Workstations' { if ( $productType -eq 1 ) { '1' } else { $null } }
        'Windows Servers' { if ( $productType -ne 1 ) { '1' } else { $null } }
        Default { $null }
    }

    #Duo UserNameFormat
    $cfDuoUsernameformatID = Ninja-Property-Get 'cpvalDuoUsernameformat'
    $cfDuoUsernameformatOption = Ninja-Property-Options 'cpvalDuoUsernameformat'
    if($cfDuoUsernameformatID) {
      $cfDuoUsernameformat = $($($cfDuoUsernameformatOption -match [Regex]::Escape($cfDuoUsernameformatID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoUsernameformat)) {
        $userNameFormat = $cfDuoUsernameformat  # NinjaRMM custom field
    }
    $userNameFormat = Switch ($userNameFormat) {
        '0' { '0' }
        '1' { '1' }
        '2' { '2' }
        Default { $null }
    }

    #Duo UAC_ProtectMode
    $cfDuoUacprotectmodeID = Ninja-Property-Get 'cpvalDuoUacprotectmode'
    $cfDuoUacprotectmodeOption = Ninja-Property-Options 'cpvalDuoUacprotectmode'
    if ($cfDuoUacprotectmodeID) {
    $cfDuoUacprotectmode = $($($cfDuoUacprotectmodeOption -match [Regex]::Escape($cfDuoUacprotectmodeID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoUacprotectmode)) {
        $uacProtectMode = $cfDuoUacprotectmode  # NinjaRMM custom field
    }
    $uacProtectMode = Switch ($uacProtectMode) {
        '0' { '0' }
        '1' { '1' }
        '2' { '2' }
        Default { $null }
    }

    #Duo  UAC_Offline
    $cfDuoUacofflineID = Ninja-Property-Get 'cpvalDuoUacoffline'
    $cfDuoUacofflineOption = Ninja-Property-Options 'cpvalDuoUacoffline'
    if ($cfDuoUacofflineID) {
      $cfDuoUacoffline = $($($cfDuoUacofflineOption -match [Regex]::Escape($cfDuoUacofflineID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoUacoffline)) {
        $uacOffline = $cfDuoUacoffline  # NinjaRMM custom field
    }
    $uacOffline = Switch ($uacOffline) {
        '0' { '0' }
        '1' { '1' }
        Default { $null }
    }

    #Duo UAC_Offline_Enroll
    $cfDuoUacofflineenrollID = Ninja-Property-Get 'cpvalDuoUacofflineenroll'
    $cfDuoUacofflineenrollOption = Ninja-Property-Options 'cpvalDuoUacofflineenroll'
    if ($cfDuoUacofflineenrollID){
      $cfDuoUacofflineenroll = $($($cfDuoUacofflineenrollOption -match [Regex]::Escape($cfDuoUacofflineenrollID)).split('='))[1]
    }
    if (-not [string]::IsNullOrEmpty($cfDuoUacofflineenroll)) {
        $uacOfflineEnroll = $cfDuoUacofflineenroll  # NinjaRMM custom field
    }
    $uacOfflineEnroll = Switch ($uacOfflineEnroll) {
        '0' { '0' }
        '1' { '1' }
        Default { $null }
    }
    #regionEnd

    #region Variables - Configure script environment and define constants
    # Suppress progress bars for cleaner output in automated environments
    $ProgressPreference = 'SilentlyContinue'
    # Disable confirmation prompts to allow unattended execution
    $ConfirmPreference = 'None'
    # Enforce TLS 1.2 for secure network communications
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

    # Define core script parameters
    $appName = 'Duo-win-login'  # Base name for project-related files
    $workingDirectory = 'C:\ProgramData\_automation\app\{0}' -f $appName  # Centralized working directory
    $appPath = '{0}\{1}.exe' -f $workingDirectory, $appName  # Full path to installation script
    $appDownloadUrl = 'https://dl.duosecurity.com/duo-win-login-latest.exe'  # DUO latest version download url
    $hashUrl = 'https://duo.com/docs/checksums#duo-windows-logon' #File Hash for latest Duo Installer

    #region workingDirectory - Prepare clean execution environment
    # Remove existing directory to prevent file conflicts
    Remove-Item -Path $workingDirectory -Recurse -Force -ErrorAction SilentlyContinue

    # Create fresh working directory with error handling
    if (-not (Test-Path $workingDirectory)) {
        try {
            New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            throw ('Error: Failed to Create {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
        }
    }

    # Ensure full permissions for automated operations
    if (-not ( ( ( Get-Acl $workingDirectory ).Access | Where-Object { $_.IdentityReference -Match 'EveryOne' } ).FileSystemRights -Match 'FullControl' )) {
        $acl = Get-Acl $workingDirectory
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
        $acl.AddAccessRule($AccessRule)
        Set-Acl $workingDirectory $acl -ErrorAction SilentlyContinue
    }
    #endRegion
}

Process {
    #region Remove erroneous directory
    $pathToRemove = 'C:\Windows\Temp\{4804031F-0496-4E9A-BD3D-E6B637D29EA7}'
    if (Test-Path -Path $pathToRemove) {
        try {
            Remove-Item -Path $pathToRemove -Force -Recurse -ErrorAction Stop
        } catch {
            Write-Information ('Warning: Failed to remove ''{0}''. Proceeding with installation without removing the directory.' -f $pathToRemove) -InformationAction Continue
        }
    }
    #endRegion

    #region Version Comparison
    try {
        $iwrHeader = Invoke-WebRequest -Uri $appDownloadUrl -UseBasicParsing -Method Head -ErrorAction Stop
    } catch {
        throw ('Error: Unable to reach download Url ({0}). A security application or firewall rule seem to be preventing it.' -f $appDownloadUrl)
    }
    $fileName = ($iwrHeader.Headers.'Content-Disposition' -split '=')[-1] -replace '"', ''
    [Version]$latestVersion = $fileName -replace 'duo-win-login-', '' -replace '\.exe', ''

    $installedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -match 'Duo Authentication for Windows Logon' } |
        Select-Object -ExpandProperty DisplayVersion

    if ($installedVersion) {
        if ([Version]$latestVersion -le [Version]$installedVersion) {
            return 'Information: Latest version {0} of Duo Authentication for Windows Logon is already installed' -f $installedVersion
        } else {
            Write-Information ('Information: Installed Version: {0}; Latest Version: {1}' -f $installedVersion, $latestVersion) -InformationAction Continue
        }
    } else {
        Write-Information ('Information: Duo Authentication for Windows Logon is not installed. Installing the latest version {0}' -f $latestVersion) -InformationAction Continue
    }
    #endRegion

    #region Download Installer
    try {
        Invoke-WebRequest -Uri $appDownloadUrl -OutFile $appPath -UseBasicParsing -ErrorAction Stop
    } catch {
        throw ('Error: Failed to download installer from the download url: {0}. Reason: {1}' -f $appDownloadUrl, $($Error[0].Exception.Message))
    }
    #endRegion

    #region Compare Hash
    try {
        $iwrHash = Invoke-WebRequest -Uri $hashUrl -UseBasicParsing -ErrorAction Stop
    } catch {
        throw ('Error: Unable to reach Url ({0}) to fetch authentic file hash. A security application or firewall rule seem to be preventing it.' -f $hashUrl)
    }
    $iwrhash.RawContent -match "([a-z0-9]{64}) +$fileName" | Out-Null
    $authenticHash = $matches[1]

    $downloadedFileHash = (Get-FileHash -Path $appPath -Algorithm SHA256).Hash

    if ($downloadedFileHash -ne $authenticHash) {
        throw ('Error: SHA256 Hash of the installer downloaded from the download url {0} is not matching the Authentic Hash provided by vendor at {1}. Authentic Hash: {2}; Downloaded Installer Hash: {3}' -f $appDownloadUrl, $hashUrl, $authenticHash, $downloadedFileHash)
    }
    #endRegion

    #region Create Parameter
    $additionalArguments = ''

    if ($autoPush -in ('0', '1')) {
        $additionalArguments = '{0} AUTOPUSH="#{1}"' -f $additionalArguments, $autoPush
    }

    if ($failOpen -in ('0', '1')) {
        $additionalArguments = '{0} FAILOPEN="#{1}"' -f $additionalArguments, $failOpen
    }

    if ($rdpOnly -in ('0', '1')) {
        $additionalArguments = '{0} RDPONLY="#{1}"' -f $additionalArguments, $rdpOnly
    }

    if ($smartCard -in ('0', '1')) {
        $additionalArguments = '{0} SMARTCARD="#{1}"' -f $additionalArguments, $smartCard
    }

    if ($wrapSmartCard -in ('0', '1')) {
        $additionalArguments = '{0} WRAPSMARTCARD="#{1}"' -f $additionalArguments, $wrapSmartCard
    }

    if ($enableOffline -in ('0', '1')) {
        $additionalArguments = '{0} ENABLEOFFLINE="#{1}"' -f $additionalArguments, $enableOffline
    }

    if ($userNameFormat -in ('0', '1', '2')) {
        $additionalArguments = '{0} USERNAMEFORMAT="#{1}"' -f $additionalArguments, $userNameFormat
    }

    if ($uacProtectMode -in ('0', '1', '2')) {
        $additionalArguments = '{0} UAC_PROTECTMODE="#{1}"' -f $additionalArguments, $uacProtectMode
    }

    if ($uacOffline -in ('0', '1')) {
        $additionalArguments = '{0} UAC_OFFLINE="#{1}"' -f $additionalArguments, $uacOffline
    }

    if ($uacOfflineEnroll -in ('0', '1')) {
        $additionalArguments = '{0} UAC_OFFLINE_ENROLL="#{1}"' -f $additionalArguments, $uacOfflineEnroll
    }

    $argument = '/S /V" /qn IKEY="{0}" SKEY="{1}" HOST="{2}" {3}"' -f $iKey, $sKey, $hKey, $additionalArguments.Trim()

    Write-Information ('Information: Installation Arguments: {0}' -f $argument) -InformationAction Continue
    #endRegion

    #region Install
    Unblock-File -Path $appPath -ErrorAction SilentlyContinue

    try {
        Start-Process -FilePath $appPath -ArgumentList $argument -Wait -ErrorAction Stop
    } catch {
        throw ('Error: Failed to initiate the install process. Reason: {0}' -f $Error[0].Exception.Message)
    }
    #endRegion

    #region Validation
    Start-Sleep -Seconds 30

    $installedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -match 'Duo Authentication for Windows Logon' } |
        Select-Object -ExpandProperty DisplayVersion

    if ($installedVersion) {
        if ([Version]$latestVersion -le [Version]$installedVersion) {
            return 'Information: Successfully installed the latest version {0} of Duo Authentication for Windows Logon.' -f $installedVersion
        } else {
            throw ('Error: Failed to update Duo Authentication for Windows Logon to the latest version: {0}. Installed Version is {1}.' -f $latestVersion, $installedVersion)
        }
    } else {
        throw ('Error: Failed to install the latest version {0} of Duo Authentication for Windows Logon.' -f $latestVersion)
    }
    #endRegion
}

End {
    #region Cleanup
    Get-ChildItem $workingDirectory -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
    #endRegion
}
