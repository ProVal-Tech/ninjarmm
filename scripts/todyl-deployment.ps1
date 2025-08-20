<#
.SYNOPSIS
    Installs the Todyl SGN Connect agent on Windows systems using the appropriate deployment key for servers, laptops, or desktops.

.DESCRIPTION
    - Downloads the latest SGN Connect installer.
    - Determines the machine type (server, laptop, desktop).
    - Retrieves the correct deployment key from Ninja organization properties.
    - Runs the installer silently with the deployment key.
    - Launches SGN Connect if installation succeeds.
    - Cleans up the installer file after installation.

.NOTES
    [script]
    name = "Todyl Deployment Script"
    description = "This script deploys Todyl Agent (SGN Connect) on the windows machines."
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
    $ProjectName     = 'Todyl'
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
        Write-Output "PC is a laptop, setting key to laptopDeploymentKey: $laptopDeploymentKey"
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
        Write-Output "Desktop Key: $desktopDeploymentKey"
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

End {
    # Cleanup installer
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
    }
}
