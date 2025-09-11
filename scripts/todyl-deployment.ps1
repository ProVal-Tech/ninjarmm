<#
.SYNOPSIS
    Installs or updates the Todyl SGN Connect agent on Windows systems using the appropriate deployment key.

.DESCRIPTION
    - Downloads the latest SGN Connect installer.
    - Determines the machine type (server, laptop, desktop).
    - Retrieves the correct deployment key from Ninja organization properties.
    - Compares installed SGN Connect version with downloaded installer version.
    - Runs the installer silently if installation is required.
    - Launches SGN Connect if installation succeeds.
    - Cleans up the installer file after installation.

.NOTES
    [script]
    name = "Todyl Deployment"
    description = "This script automates the deployment and update of the Todyl Agent (SGN Connect) on Windows machines by downloading the latest installer, running the installation silently, and validating that the agent has been successfully installed."
    categories = ["Proval"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

Begin {
    # Ensure TLS 1.2 is used for secure download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Disable progress bar for faster execution
    $ProgressPreference = 'SilentlyContinue'

    # Variables
    $ProjectName      = 'Todyl'
    $WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
    $installerPath    = Join-Path $WorkingDirectory "SGNConnect_Latest.exe"

    # Create working directory if it doesn't exist
    if (-not (Test-Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
    }

    # Download SGN Connect installer
    Invoke-WebRequest "https://download.todyl.com/sgn_connect/SGNConnect_Latest.exe" -OutFile $installerPath

    # Retrieve deployment keys from Ninja properties
    $laptopDeploymentKey  = Ninja-Property-Get -Type Organization -Name cpvalTodylLaptopPolicyKey
    $desktopDeploymentKey = Ninja-Property-Get -Type Organization -Name cpvalTodylDesktopPolicyKey
    $serverDeploymentKey  = Ninja-Property-Get -Type Organization -Name cpvalTodylServerPolicyKey

    $todylKey = $null
}

Process {
    # --- Check installed version ---
    $installedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                                           'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -match 'sgn connect' } |
        Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue

    if ($installedVersion) {
        Write-Output "Installed SGN Connect Version: $installedVersion"
    } else {
        Write-Output "SGN Connect not currently installed."
    }

    # --- Check downloaded installer version ---
    $versionInfo    = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installerPath)
    $downloadedVersion = $versionInfo.FileVersion
    Write-Output "Downloaded Installer Version: $downloadedVersion"

    $installRequired = $false
    if (-not $installedVersion) {
        Write-Output "No existing installation found, installation required."
        $installRequired = $true
    }
    elseif ([version]$downloadedVersion -gt [version]$installedVersion) {
        Write-Output "Update required: Installed version ($installedVersion) is older than downloaded version ($downloadedVersion)."
        $installRequired = $true
    }
    else {
        Write-Output "SGN Connect is up-to-date (Installed: $installedVersion, Downloaded: $downloadedVersion). Skipping installation."
    }

    if ($installRequired) {
        # Identify machine type
        $ComputerSystem = Get-CimInstance Win32_ComputerSystem
        $MyOS           = (Get-CimInstance Win32_OperatingSystem).ProductType

        if ($MyOS -gt 1) {
            Write-Output "PC is a server, setting key to serverDeploymentKey"
            if ([string]::IsNullOrEmpty($serverDeploymentKey)) {
                Write-Output "Todyl Server Key not supplied, exiting"
                return
            }
            $todylKey = $serverDeploymentKey
        }
        elseif ($ComputerSystem.PCSystemType -eq 2) {
            Write-Output "PC is a laptop, setting key to laptopDeploymentKey"
            if ([string]::IsNullOrEmpty($laptopDeploymentKey)) {
                Write-Output "Todyl Laptop Key not supplied, exiting"
                return
            }
            $todylKey = $laptopDeploymentKey
        }
        else {
            Write-Output "PC is a desktop, setting key to desktopDeploymentKey"
            if ([string]::IsNullOrEmpty($desktopDeploymentKey)) {
                Write-Output "Todyl Desktop Key not supplied, exiting"
                return
            }
            $todylKey = $desktopDeploymentKey
        }

        # Run SGN Connect installer silently with deployment key
        $proc = Start-Process -FilePath $installerPath -ArgumentList "/silent /deployKey $todylKey" -Wait -PassThru
        Write-Output "Exit Code: $($proc.ExitCode)"

        if ($proc.ExitCode -eq 0) {
            $sgnPath = "C:\Program Files\SGN Connect\Current\sgnconnect.exe"
            if (Test-Path $sgnPath) {
                Start-Process $sgnPath
            } else {
                Write-Output "SGN Connect executable not found at expected path."
            }
        }
    }
}

End {
    # Cleanup installer
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
    }
}
