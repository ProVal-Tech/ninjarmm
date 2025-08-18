<#
.SYNOPSIS
Installs the SentinelOne agent if not already installed.

.DESCRIPTION
This script checks for the existing SentinelOne agent installation by verifying a specific registry path.
If the agent is not installed, it downloads the correct MSI installer (based on OS architecture) from a predefined URI, 
installs it silently with the provided site token, and validates the installation after execution.


.NOTES
    [script]
    name = "SentinelOne Deployment"
    description = "This script deploys Sentinelone agent on Windows machines."
    categories = ["Proval"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

Begin {
    # Variables
    $regInstallPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SentinelAgent\config'
    $siteToken = Ninja-Property-Get -Type Organization -Name cpvalSentineloneKey
    $ProjectName = 'SentinelOne'
    $WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
    $installerPath = "$WorkingDirectory\SentinelOneAgent-Windows.msi"
    $bitness = if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' }
    $downloadUri = "https://cwa.connectwise.com/tools/sentinelone/SentinelOneAgent-Windows_${bitness}bit.msi"

    # Ensure directories exist
    if (-not (Test-Path $WorkingDirectory)) {
            New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
    }

    # Force TLS 1.2 for compatibility
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
}

Process {
    # Check if SentinelOne is already installed
    if (Test-Path -Path $regInstallPath) {
        Write-Output 'SUCCESS - SentinelOne agent already installed.'
        return
    }

    # Download the installer
    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-Output "ERROR - Failed to download installer: $($_.Exception.Message)"
        return
    }

    # Verify download
    if (!(Test-Path $installerPath)) {
        Write-Output 'ERROR - File download failed.'
        return
    }

    # Install SentinelOne silently
    try {
        Start-Process -FilePath "$env:windir\system32\msiexec.exe" `
            -ArgumentList '/i', "`"$installerPath`"", "SITE_TOKEN=$siteToken", '/QUIET', '/NORESTART', '/L*V', "`"$WorkingDirectory\S1Install.log`"" `
            -Wait -NoNewWindow
    } catch {
        Write-Output "ERROR - Failed to start installer: $($_.Exception.Message)"
        return
    }
}

End {
    # Verify installation
    if (Test-Path -Path $regInstallPath) {
        Write-Output 'SUCCESS - SentinelOne agent installed.'
    } else {
        Write-Output 'ERROR - SentinelOne agent failed to install.'
    }
}
