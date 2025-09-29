<#
.SYNOPSIS
    This script will remove previous installations of Windows, including the contents of the 'C:\Windows.old' directory, if found on the endpoint.

.NOTES
    [script]
    name = "Remove Windows.old - Windows"
    description = "This script will remove previous installations of Windows, including the contents of the 'C:\Windows.old' directory, if found on the endpoint. A reboot may be required to remove the empty 'C:\Windows.old' folder after the script has completed."
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
            if ($key -like "*Previous Installations") {
            New-ItemProperty -Path $key.PSPath -Name StateFlags1719 -Value 2 -Type DWORD -Force | Out-Null
            }
        }
        
        # Run Disk Cleanup silently with preset options
        Start-Process -Wait "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:1719"
    }
}

End {
    $newFreeSpaceGB = (Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" |
                       Select-Object -ExpandProperty FreeSpace) / 1GB -as [float]

    Write-Output "Previous Drive Space Available = $freeSpaceGB GB"
    Write-Output "Current Drive Space Available = $newFreeSpaceGB GB"
}