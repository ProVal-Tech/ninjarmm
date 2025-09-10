<#
.SYNOPSIS
    Installs or updates the SentinelOne agent.

.DESCRIPTION
    - Checks if the SentinelOne agent is installed by registry key.
    - Reads installed agent version.
    - Downloads the correct MSI installer (based on OS architecture).
    - Extracts MSI ProductVersion before installing.
    - Compares versions, installs/updates only if newer (unless -ForceUpdate).
    - Logs all actions.
#>



Begin {
    # Variables
    $regInstallPath   = 'HKLM:\SOFTWARE\SentinelOne\Sentinel Agent'
    $siteToken        = Ninja-Property-Get -Type Organization -Name cpvalSentineloneKey
    $ProjectName      = 'SentinelOne'
    $WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
    $installerPath    = Join-Path $WorkingDirectory 'SentinelOneAgent-Windows.msi'
    $bitness          = if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' }
    $downloadUri      = "https://cwa.connectwise.com/tools/sentinelone/SentinelOneAgent-Windows_${bitness}bit.msi"

    # Ensure directories exist
    try {
        if (-not (Test-Path $WorkingDirectory)) {
            New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        }
    } catch {
        Write-Output "ERROR - Failed to create working directory: $($_.Exception.Message)"
        exit 1
    }

    # Force TLS 1.2 for compatibility
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Helper: get MSI file version
    function Get-MsiProductVersion {
        param([string]$MsiPath)
        try {
            $installer = New-Object -ComObject WindowsInstaller.Installer
            $database  = $installer.OpenDatabase($MsiPath, 0)
            $query     = "SELECT `Value` FROM `Property` WHERE `Property`='ProductVersion'"
            $view      = $database.OpenView($query)
            $view.Execute()
            $record    = $view.Fetch()
            $version   = $record.StringData(1)
            $view.Close()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($installer) | Out-Null
            return $version
        } catch {
            Write-Output "ERROR - Unable to read MSI version: $($_.Exception.Message)"
            return $null
        }
    }
}

Process {
    # Get installed version (from uninstall keys)
    $installedVersion = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                                             'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
    Get-ItemProperty -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'SentinelOne' -or $_.DisplayName -match 'Sentinel Agent' } |
    Select-Object -ExpandProperty DisplayVersion -First 1 -ErrorAction SilentlyContinue

    if ($installedVersion) {
        Write-Output "Detected installed version: $installedVersion"
    } else {
        Write-Output "No existing SentinelOne installation detected."
    }

    # Download the installer
    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        Write-Output "Downloaded installer to: $installerPath"
    } catch {
        Write-Output "ERROR - Failed to download installer: $($_.Exception.Message)"
        exit 1
    }

    # Verify download
    if (!(Test-Path $installerPath)) {
        Write-Output "ERROR - File download failed."
        exit 1
    }

    # Get MSI version
    $installerVersion = Get-MsiProductVersion -MsiPath $installerPath
    if (-not $installerVersion) {
        Write-Output "ERROR - Could not determine installer version."
        exit 1
    }
    Write-Output "Installer version: $installerVersion"

    # Compare versions
    $needsUpdate = $true
    if ($installedVersion) {
        try {
            $installedVerObj  = [version]$installedVersion
            $installerVerObj  = [version]$installerVersion
            if ($installedVerObj -ge $installerVerObj ) {
                Write-Output "SUCCESS - SentinelOne already up to date ($installedVersion)."
                $needsUpdate = $false
            } else {
                Write-Output "INFO - Update required. Installed: $installedVersion, Available: $installerVersion"
            }
        } catch {
            Write-Output "WARNING - Version comparison failed, proceeding with install."
        }
    }

    if ($needsUpdate) {
        try {
            $arguments = @(
                '/i', "`"$installerPath`"",
                "SITE_TOKEN=$siteToken",
                '/QUIET',
                '/NORESTART',
                '/L*V', "`"$WorkingDirectory\S1Install.log`""
            )

            Start-Process -FilePath "$env:windir\system32\msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow
            Write-Output "INFO - Installation attempted."
        } catch {
            Write-Output "ERROR - Failed to start installer: $($_.Exception.Message)"
            exit 1
        }
    }
}

End {
    # Verify installation
    if (Test-Path $regInstallPath) {
        Write-Output "SUCCESS - SentinelOne agent installed or updated successfully."
    } else {
        Write-Output "ERROR - SentinelOne agent installation failed."
    }
}
