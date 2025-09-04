<#
.SYNOPSIS
    Installs the MSP360 PowerShell module and the MSP360 Online Backup Agent (MBSAgent) using a URL from NinjaRMM Custom Field 'cPVAL MSP 360 Url'.

.DESCRIPTION
    This script automates the installation of the MSP360 PowerShell module and the MSP360 Online Backup Agent.
    It retrieves the installation URL from a NinjaRMM custom field 'cPVAL MSP 360 Url', ensures the required TLS version is set,
    installs the necessary PowerShell modules, and then installs the MBSAgent.
    After installation, it validates the success by checking the Windows uninstall registry.

.EXAMPLE
    .\Install-MSP360Agent.ps1
    Installs the MSP360 module and agent using the URL from NinjaRMM Custom Field 'cPVAL MSP 360 Url'.

.NOTES
    [script]
    name = "Install MSP360 Online Backup"
    description = "Installs the MSP360 PowerShell module and the MSP360 Online Backup Agent (MBSAgent) using a URL from NinjaRMM Custom Field 'cPVAL MSP 360 Url'."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

begin {
    # region globals
    $ProgressPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    #endRegion

    #region Variables
    $ninjaCustomField = 'cpvalMsp360Url'
    $softwareName = 'Online Backup'
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    #endRegion

    #region Functions
    function Install-MSP360Module {
        #region Parameters
        [CmdletBinding()]
        param (
            [Parameter()]
            [bool] $AllowAlpha,
            [Parameter()]
            [string] $RequiredVersion,
            [Parameter()]
            [switch] $CleanInstall
        )

        #region Install MSP360 PowerShell Module
        @(
            @{
                Module = 'PackageManagement'
                Version = '1.4.6'
            },
            @{
                Module = 'PowerShellGet'
                Version = '2.2.3'
            }
        ) | ForEach-Object -Process {
            if ($Host.Version.Major -lt 5) {
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

                if ((Get-Module $_.Module -ListAvailable -ErrorAction SilentlyContinue).Version -lt [System.Version]$_.Version) {
                    (New-Object Net.WebClient).DownloadFile(
                        "https://www.powershellgallery.com/api/v2/package/$($_.Module)",
                        "$ENV:TEMP\$($_.Module).zip"
                    )
                    $Null = New-Item -Path "$ENV:windir\System32\WindowsPowerShell\v1.0\Modules" -Name $_.Module -ItemType 'directory' -ErrorAction SilentlyContinue
                    [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory(
                        ([System.IO.Compression.ZipFile]::Open("$ENV:TEMP\$($_.Module).zip", 'read')),
                        "$ENV:windir\System32\WindowsPowerShell\v1.0\Modules\$($_.Module)"
                    )
                }
            } else {
                if ((Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1).Version -lt [System.Version]'2.8.5.201') {
                    $Null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                }

                if ((Get-Module $_.Module -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1).Version -lt [System.Version]$_.Version) {
                    $Null = Install-Module -Name $_.Module -MinimumVersion $_.Version -Force -AllowClobber -Repository 'PSGallery'
                    $Null = Remove-Module -Name $_.Module -Force -WarningAction SilentlyContinue
                    $Null = Import-Module -Name $_.Module -MinimumVersion $_.Version -Force
                } else {
                    $Null = Import-Module -Name $_.Module -MinimumVersion $_.Version -Force
                }
            }
        }

        $Null = Import-PackageProvider -Name 'PowerShellGet' -Force -MinimumVersion 2.2

        if ($CleanInstall) {
            Uninstall-Module -Name 'msp360' -AllVersions -ErrorAction SilentlyContinue
        } else {
            $LatestInstalledVersion = [System.Version](Get-InstalledModule -Name 'msp360' -ErrorAction SilentlyContinue).Version
            if ($LatestInstalledVersion) {
                if (
                    ($LatestInstalledVersion.Major -lt 2) -and
                    ((-not($RequiredVersion)) -or ([System.Version]$RequiredVersion -ge [System.Version]'2.0.0'))
                ) {
                    Write-Warning -Message "Latest installed MSP360 PowerShell Module version is $($LatestInstalledVersion.ToString()). New version of the module is signed with an updated digital certificate. Uninstalling previous versions of the module before update..."
                    Uninstall-Module -Name 'msp360' -AllVersions
                }
            }
        }

        $ModuleInstallOptions = @{
            Force = $true
        }

        if ($RequiredVersion) {
            $ModuleInstallOptions.Add('RequiredVersion', $RequiredVersion)
        }

        if ($AllowAlpha) {
            $ModuleInstallOptions.Add('AllowPrerelease', $true)
            Register-PSRepository -Name 'MSP360' -SourceLocation 'http://18.159.222.66/nuget/MSP360/' -InstallationPolicy Trusted
            $ModuleInstallOptions.Add('Repository', 'MSP360')
        }

        Install-Module -Name 'msp360' @ModuleInstallOptions
        Import-Module -Name 'msp360' -Force
    }
    #endRegion
} process {
    #region NinjaRMM Info
    $url = Ninja-Property-Get $ninjaCustomField
    if ([string]::IsNullOrEmpty($url)) {
        Write-Information 'NinjaRMM URL is not set.' -InformationAction Continue
        exit 1
    }
    #endRegion

    #region Set TLS version
    $supportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
    if ( ($supportedTLSversions -contains 'Tls13') -and ($supportedTLSversions -contains 'Tls12') ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
    } elseif ( $supportedTLSversions -contains 'Tls12' ) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    } else {
        throw 'TLS 1.2 or TLS 1.3 is not supported on this system. Please install ''KB3140245'' to fix this issue.'
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            throw 'PowerShell 2 / .NET 2.0 does not support TLS 1.2.'
        }
    }

    #region import module
    try {
        Install-MSP360Module -ErrorAction Stop
    } catch {
        Write-Information ('Failed to install MSP360 module. Reason: {0}' -f $Error[0].Exception.Message) -InformationAction Continue
        exit 1
    }
    #endRegion

    #region Install MBSAgent
    try {
        Install-MBSAgent -URL $url -Force -ErrorAction Stop
        Write-Information 'Successfully installed MBSAgent.' -InformationAction Continue
        exit 0
    } catch {
        Write-Information ('Failed to install MBSAgent. Reason: {0}' -f $Error[0].Exception.Message) -InformationAction Continue
        exit 1
    }
    #endRegion
} end {
    #region Validation
    $uninstallInfo = Get-ChildItem $uninstallPaths -ErrorAction SilentlyContinue |
        Get-ItemProperty |
        Where-Object { 
            $_.DisplayName -match [Regex]::Escape($SoftwareName)
        }
    if ($uninstallInfo) {
        Write-Information 'Installation was successful.' -InformationAction Continue
        exit 0
    } else {
        Write-Information 'Installation failed.' -InformationAction Continue
        exit 1
    }
    #endRegion
}