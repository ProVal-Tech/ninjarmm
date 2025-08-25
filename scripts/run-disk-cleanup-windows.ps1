<#
.SYNOPSIS
Performs a disk cleanup on the system drive.

.DESCRIPTION
This script identifies the system drive, calculates its available space before and after cleanup,
and executes the built-in Windows Disk Cleanup utility (`cleanmgr.exe`) in automated mode.
The Downloads folder is excluded from cleanup.

.NOTES
    [script]
    name = "Run Disk Cleanup - Windows"
    description = "Runs the Cleanmgr included in Windows. It will set all optional Cleanmgr targets to enabled except for the Downloads folder."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

Begin {
    # Ensure required environment and drive info
    $osDrive = Get-CimInstance -Class Win32_OperatingSystem | 
               Select-Object -ExpandProperty SystemDrive
    
    $freeSpaceGB = (Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" |
                    Select-Object -ExpandProperty FreeSpace) / 1GB -as [float]

    Write-Verbose "System Drive Detected: $osDrive"
    Write-Verbose "Initial Free Space: $freeSpaceGB GB"
}

Process {
    if (Test-Path -Path "$env:SystemRoot\System32\cleanmgr.exe") {
        # Stop any running cleanmgr processes
        Get-Process cleanmgr -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

        # Configure cleanup options (excluding Downloads folder)
        $volumeCaches = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        foreach ($key in $volumeCaches) {
            if ($key -like "*DownloadsFolder") { continue }
            New-ItemProperty -Path $key.PSPath -Name StateFlags1619 -Value 2 -Type DWORD -Force | Out-Null
        }

        # Run Disk Cleanup silently with preset options
        Start-Process -Wait "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:1619"
    }
}

End {
    $newFreeSpaceGB = (Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" |
                       Select-Object -ExpandProperty FreeSpace) / 1GB -as [float]

    Write-Output "Previous Drive Space Available = $freeSpaceGB GB"
    Write-Output "Current Drive Space Available = $newFreeSpaceGB GB"
}
