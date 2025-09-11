<#
.SYNOPSIS
    Installs/Updates the Zorus Agent (Archon Agent) on Windows systems.

.DESCRIPTION
    - Checks if the Zorus Agent is already installed.
    - Retrieves deployment token from Ninja organization properties.
    - Downloads the Zorus installer.
    - Installs/updates the agent with provided token and optional uninstall password.
    - Cleans up temporary files after installation.
    - Restores original .NET security protocol settings.

.NOTES
    [script]
    name = "Zorus Deployment"
    description = "This script automates the deployment and update of the Zorus agent (Archon Agent) across Windows machines by downloading the required installer, executing the installation silently, and verifying that the agent is successfully installed."
    categories = ["Proval"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

Begin {
    $Token     = Ninja-Property-Get -Type Organization -Name 'cpvalZorusTokenKey'
    $Password  = Ninja-Property-Get -Type Organization -Name 'cpvalZorusUninstallationPassword'
    $HideFromAddRemove = 1   # Default to hide from Add/Remove programs (0 = show, 1 = hide)

    $originalProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::SystemDefault



    # --- Token Must be Set ---
    if ([string]::IsNullOrEmpty($Token)) {
        Throw "Deployment token not provided. Exiting."
    }

    $source       = "https://static.zorustech.com/downloads/ZorusInstaller.exe"
    $ProjectName  = 'Zorus'
    $WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
    $destination  = Join-Path $WorkingDirectory "ZorusInstaller.exe"
}

Process {
    # --- Ensure working directory exists ---
    if (-not (Test-Path -Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
    }

    # --- Download the installer ---
    Write-Output "Downloading Zorus Deployment Agent..."
    try {
        Invoke-WebRequest -Uri $source -OutFile $destination -UseBasicParsing
    }
    catch {
        Throw "Failed to download installer from $source. Exiting."
    }

    # --- Check installed version (if any) ---
    $installedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                                             'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
                        Get-ItemProperty |
                        Where-Object { $_.DisplayName -match 'Archon' } |
                        Select-Object -ExpandProperty DisplayVersion -First 1 -ErrorAction SilentlyContinue

    if ($installedVersion) {
        Write-Output "Installed Zorus Version: $installedVersion"
    } else {
        Write-Output "Zorus agent not currently installed."
    }

    # --- Check downloaded installer version ---
    $versionInfo       = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($destination)
    $downloadedVersion = $versionInfo.FileVersion
    Write-Output "Downloaded Installer Version: $downloadedVersion"

    # --- Determine if installation required ---
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
        Write-Output "Zorus is up-to-date (Installed: $installedVersion, Downloaded: $downloadedVersion). Skipping installation."
    }

    # --- Perform installation if required ---
    if ($installRequired) {
        $arguments = @("/qn", "ARCHON_TOKEN=$Token", "HIDE_ADD_REMOVE=$HideFromAddRemove")
        if (-not [string]::IsNullOrEmpty($Password)) {
            $arguments += "UNINSTALL_PASSWORD=$Password"
            Write-Output "Installing Zorus Deployment Agent with uninstall password..."
        } else {
            Write-Output "Installing Zorus Deployment Agent..."
        }

        Start-Process -FilePath $destination -ArgumentList $arguments -Wait -NoNewWindow
        Write-Output "Zorus Deployment Agent installation and configuration complete."
    }
}

End {
    Write-Output "Removing temporary files..."
    try {
        Remove-Item -Path $destination -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to remove installer at $destination"
    }

    [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol
    Write-Output "Installation process finished."
}
