<#
.SYNOPSIS
    Uninstalls Cisco Secure Client from Windows systems.

.DESCRIPTION
    This script is designed to be executed as an ad-hoc script from NinjaRMM and facilitates the removal
    of Cisco Secure Client from Windows systems by detecting installed instances through the Windows Registry
    and performing a silent uninstallation using msiexec.

    The script performs the following operations:
    - Searches the Windows Registry for installed Cisco Secure Client instances
    - Retrieves the Product ID (GUID) for each detected installation
    - Executes a silent uninstallation using msiexec with quiet mode and no restart
    - Verifies successful removal by checking the registry again
    - Reports the uninstallation status and handles failures appropriately

    This script operates independently without requiring any custom field configuration or parameters,
    making it suitable for ad-hoc execution through NinjaRMM's script execution feature.

.NOTES
    name = "Cisco Secure Client - Package Uninstallation [Windows]"
    description = "Removes Cisco Secure Client from Windows systems by detecting installed instances in the Windows Registry and performing a silent uninstallation. Applicable for Windows systems."
    categories = "ProVal"
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

.COMPONENT
    This script does not require any NinjaRMM custom fields or parameters. It operates independently and
    can be executed as an ad-hoc script through NinjaRMM's script execution feature. The script searches
    for Cisco Secure Client installations automatically and handles the uninstallation process without
    user intervention or configuration.

.EXAMPLE
    This script is typically executed as an ad-hoc script from NinjaRMM. No configuration is required.

    Example workflow:
    1. Navigate to the target device in NinjaRMM
    2. Execute this script as an ad-hoc script
    3. The script will automatically detect and uninstall Cisco Secure Client if present
    4. Review the output to confirm successful uninstallation

.INPUTS
    None. This script does not accept pipeline input or parameters. It operates independently and
    automatically detects installed instances of Cisco Secure Client.

.OUTPUTS
    The script writes informational messages to the console indicating:
    - Whether Cisco Secure Client is installed
    - The uninstallation status (success or failure)
    - Exit codes if uninstallation fails
    - A final success message or error if uninstallation fails

.LINK
    https://content.provaltech.com/docs/f4a79d4f-1f58-4a45-a9a1-65d402ee4988
#>

#region globals
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
#endRegion

#region variable
$softwareName = 'Cisco Secure Client'
$failureCount = 0
#endRegion

#region functions
function Get-ProductId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$SoftwareName
    )
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $uninstallInfo = Get-ChildItem $uninstallPaths -ErrorAction SilentlyContinue |
        Get-ItemProperty |
        Where-Object { 
            $_.DisplayName -match [Regex]::Escape($SoftwareName)
        }
    if ($uninstallInfo) {
        return $uninstallInfo.PSChildName
    } else {
        return $null
    }
}

function Uninstall-Software {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$ProductId
    )
    $argumentList = @(
        '/x',
        $ProductId,
        '/quiet',
        '/norestart'
    )
    $UninstallProcess = Start-Process 'msiexec.exe' -ArgumentList $argumentList -Wait -PassThru
    Start-Sleep -Seconds 5
    return $UninstallProcess
}
#endRegion

#region uninstall software
foreach ($software in $softwareName) {
    $productId = Get-ProductId -SoftwareName $software
    if ($productId) {
        $uninstallProcessInfo = Uninstall-Software -ProductId $productId
        if (!(Get-ProductId -SoftwareName $software)) {
            Write-Information -MessageData ('{0} uninstalled successfully.' -f $software) -InformationAction Continue
        } else {
            Write-Information -MessageData ('{0} uninstall failed. Uninstallation Process Exit Code: ''{1}''' -f $software, $uninstallProcessInfo.ExitCode) -InformationAction Continue
            $failureCount += 1
        }
    } else {
        Write-Information -MessageData ('{0} is not installed.' -f $software) -InformationAction Continue
    }
}
#endRegion

#region validation
if ($failureCount -ge 1) {
    throw 'Uninstall failed.'
} else {
    return ('{0} uninstalled successfully.' -f $softwareName)
}
#endRegion