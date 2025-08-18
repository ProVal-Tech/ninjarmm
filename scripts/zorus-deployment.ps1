<#
.SYNOPSIS
    Installs the Zorus Deployment Agent on Windows systems.

.DESCRIPTION
    - Checks if the Zorus Deployment Agent is already installed.
    - Retrieves deployment token from Ninja organization properties.
    - Downloads the Zorus installer.
    - Installs the agent with provided token and optional uninstall password.
    - Cleans up temporary files after installation.
    - Restores original .NET security protocol settings.

.NOTES
    [script]
    name = "Zorus Deployment"
    description = "This script automates the deployment of the Zorus agent across Windows machines by downloading the required installer, executing the installation silently, and verifying that the agent is successfully installed."
    categories = ["Proval"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

#>

Begin {
    $Token = Ninja-Property-Get 'cpvalZorusTokenKey';
    $Password = Ninja-Property-Get 'cpvalZorusUninstallationPassword';
    $addRemove = 0;

    $originalProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::'SystemDefault'

    # Determine whether or not the agent is already installed
    $InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    foreach($obj in $InstalledSoftware)
    {
        if ($obj.GetValue('DisplayName') -match "Archon")
        {
            Throw "Zorus Deployment Agent is already installed. Exiting."
        }
    }

    # Token Must be Set
    if ([string]::IsNullOrEmpty($Token))
    {
        Throw "Deployment token not provided. Exiting."
    }

    $source = "https://static.zorustech.com/downloads/ZorusInstaller.exe"
    $ProjectName = 'Zorus'
    $WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
    $destination = "$WorkingDirectory\ZorusInstaller.exe"
}

Process {
    # Create working directory if it does not exist
    if (-not (Test-Path -Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory | Out-Null
    }

    # Download the installer
    Write-Information "Downloading Zorus Deployment Agent..."

    try {
        Invoke-WebRequest -Uri $source -OutFile $destination
    }
    catch {
        throw "Failed to download installer. Exiting."
    }

    $arguments = "/qn", "ARCHON_TOKEN=$Token", "HIDE_ADD_REMOVE=$HideFromAddRemove"
    if (-not [string]::IsNullOrEmpty($Password)) {
        $arguments += "UNINSTALL_PASSWORD=$Password"
        Write-Information "Installing Zorus Deployment Agent with password..."
    } else {
        Write-Information "Installing Zorus Deployment Agent..."
    }

    # Run installer
    Start-Process -FilePath $destination -ArgumentList $arguments -Wait

    Write-Information "Zorus Deployment Agent installation and configuration complete."
}

End {
    Write-Information "Removing temporary files..."
    Remove-Item -recurse $destination
    Write-Information "Installation complete."
    [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol
}
