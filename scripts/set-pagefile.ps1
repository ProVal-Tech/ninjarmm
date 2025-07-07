#requires -RunAsAdministrator
#requires -Version 5

<#
.SYNOPSIS
Configures the Windows page file settings on a specified drive, supporting both automatic and custom configurations.

.DESCRIPTION
This script allows administrators to configure the Windows page file (pagefile.sys) settings on a target system. It supports two modes of operation:

1. AutomaticManagedPagefile: Enables Windows-managed page file settings, allowing the operating system to automatically determine the size and location of the page file.
2. Custom: Disables automatic management and applies user-defined initial and maximum page file sizes on a specified drive.

The script is designed to be flexible and robust, supporting both direct execution and automation via NinjaOne RMM. It prioritizes environment variables (set by NinjaOne or other automation tools) for all parameters (Mode, DriveLetter, InitialSizeMB, MaximumSizeMB). If environment variables are not set or are invalid, it falls back to script parameters provided by the user. If neither is set, sensible defaults are used (e.g., 'Custom' for Mode, system drive for DriveLetter, 4096 MB for InitialSizeMB, 8192 MB for MaximumSizeMB).

The script normalizes the drive letter to ensure it is in the correct format (e.g., 'C:'). For custom mode, it validates that both initial and maximum page file sizes are positive integers.

All actions are wrapped in try/catch blocks to provide clear error messages if any step fails. The script checks that the specified drive exists before making changes. Output messages include details about the operation performed, the drive affected, and the page file sizes applied.

This script requires administrative privileges and PowerShell 5 or higher.

.PARAMETER Mode
Specifies whether to use automatic or custom page file settings. Use 'AutomaticManagedPagefile' to let Windows manage the page file, or 'Custom' to specify your own size and location.

.PARAMETER DriveLetter
Drive letter where the page file will be created (e.g., C:, D:). Defaults to the system drive if not specified.

.PARAMETER InitialSizeMB
Initial size of the page file in megabytes (MB). Used only in 'Custom' mode. Defaults to 4096 MB.

.PARAMETER MaximumSizeMB
Maximum size of the page file in megabytes (MB). Used only in 'Custom' mode. Defaults to 8192 MB.

.EXAMPLE
 -Mode Custom -DriveLetter D: -InitialSizeMB 4096 -MaximumSizeMB 8192

.EXAMPLE
 -Mode AutomaticManagedPagefile

.NOTES
    [script]
    name = "Set PageFile"
    description = "A brief description of the script's purpose"
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "Mode"
    description = "Specifies whether to use automatic or custom page file settings. Use 'AutomaticManagedPagefile' to let Windows manage the page file, or 'Custom' to specify your own size and location."
    type = "Drop-Down"
    mandatory = true
    default_value = "Custom"
    option_values = ["Custom", "AutomaticManagedPagefile"]
    top_option_is_default = true

    [[script.variables]]
    name = "DriveLetter"
    description = "Drive letter where the page file will be created (e.g., C:, D:). Defaults to the system drive if not specified."
    type = "String/Text"
    mandatory = false
    default_value = "C:"

    [[script.variables]]
    name = "InitialSizeMB"
    description = "Initial size of the page file in megabytes (MB). Used only in 'Custom' mode. Defaults to 4096 MB."
    type = "Integer"
    mandatory = false
    default_value = "4096"

    [[script.variables]]
    name = "MaximumSizeMB"
    description = "Maximum size of the page file in megabytes (MB). Used only in 'Custom' mode. Defaults to 8192 MB."
    type = "Integer"
    mandatory = false
    default_value = "8192"
#>

#region Parameters
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Specifies whether to use automatic or custom page file settings. Use ''AutomaticManagedPagefile'' to let Windows manage the page file, or ''Custom'' to specify your own size and location.')]
    [ValidateSet('AutomaticManagedPagefile', 'Custom')]
    [String]$Mode = 'Custom',

    [Parameter(HelpMessage = 'Drive letter where the page file will be created (e.g., C:, D:)')]
    [string]$DriveLetter = $env:SystemDrive,

    [Parameter(HelpMessage = 'Initial size of the page file in megabytes (MB)')]
    [int]$InitialSizeMB = 4096,

    [Parameter(HelpMessage = 'Maximum size of the page file in megabytes (MB)')]
    [int]$MaximumSizeMB = 8192
)
#endRegion

Begin {
    #region Ninja Variables
    # This section initializes variables for the script, prioritizing runtime variables set by NinjaOne.
    # - For each parameter (Mode, DriveLetter, InitialSizeMB, MaximumSizeMB), the script first checks if a corresponding environment variable is set by NinjaOne.
    # - If the environment variable is not set or is invalid, it falls back to the script parameter value provided by the user.
    # - If neither is set, a sensible default is used (e.g., 'Custom' for Mode, system drive for DriveLetter, 4096 MB for InitialSizeMB, 8192 MB for MaximumSizeMB).
    # - The drive letter is normalized to ensure it ends with a colon (e.g., 'C:').
    # - For 'Custom' mode, both initial and maximum page file sizes are validated to ensure they are positive integers.
    # This logic ensures the script is flexible and robust, supporting both direct execution and automation via NinjaOne.

    # Determine the mode (AutomaticManagedPagefile or Custom)
    $modeVar = $env:Mode
    $mode = if ([string]::IsNullOrEmpty($modeVar)) {
        if ([string]::IsNullOrEmpty($Mode)) {
            'Custom' # Default to Custom if not specified
        } else {
            $Mode
        }
    } else {
        $modeVar
    }

    # Determine the drive letter for the page file
    $driveLetterVar = $env:DriveLetter
    $driveLetter = if ([string]::IsNullOrEmpty($driveLetterVar)) {
        if ([string]::IsNullOrEmpty($DriveLetter)) {
            $env:SystemDrive # Default to system drive if not specified
        } else {
            $DriveLetter
        }
    } else {
        $driveLetterVar
    }

    # Ensure drive letter is in the correct format (e.g., 'C:')
    if ($driveLetter -notmatch ':$') {
        $driveLetter = '{0}:' -f $driveLetter
    }

    # If using Custom mode, determine initial and maximum page file sizes
    if ($mode -eq 'Custom') {
        # Initial size in MB
        $initialSizeMBVar = $env:InitialSizeMB
        $initialSizeMB = if (!$initialSizeMBVar -or $initialSizeMBVar -le 0) {
            if (!$InitialSizeMB -or $InitialSizeMB -le 0) {
                4096 # Default to 4096 MB if not specified
            } else {
                $InitialSizeMB
            }
        } else {
            $initialSizeMBVar
        }

        # Maximum size in MB
        $maximumSizeMBVar = $env:MaximumSizeMB
        $maximumSizeMB = if (!$maximumSizeMBVar -or $maximumSizeMBVar -le 0) {
            if (!$MaximumSizeMB -or $MaximumSizeMB -le 0) {
                8192 # Default to 8192 MB if not specified
            } else {
                $MaximumSizeMB
            }
        } else {
            $maximumSizeMBVar
        }
    }
    #endRegion
} Process {
    #region Process - Page File Configuration
    # This section validates the drive letter and applies either automatic or custom page file settings.
    # - Checks if the specified drive exists before proceeding.
    # - If 'AutomaticManagedPagefile' mode is selected, enables Windows-managed page file settings.
    #   This lets Windows automatically determine the size and location of the page file.
    # - If 'Custom' mode is selected, disables automatic management and applies user-defined initial and maximum sizes.
    #   The script updates the pagefile.sys location and size on the specified drive.
    # - All actions are wrapped in try/catch blocks to provide clear error messages if any step fails.
    # - Output messages include details about the operation performed and the parameters used.
    if (!(Test-Path -Path $driveLetter)) {
        throw ('Drive Letter: ''{0}'' not detected.' -f $driveLetter)
    }

    Switch ($mode) {
        'AutomaticManagedPagefile' {
            $pageFile = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($pageFile.AutomaticManagedPagefile -eq $false) {
                $pageFile.AutomaticManagedPagefile = $true
                try {
                    Set-CimInstance -InputObject $pageFile -ErrorAction Stop
                    return ('Enabled ''AutomaticManagedPageFile'' on ''{0}''. Windows will now manage the page file size and location automatically.' -f $driveLetter)
                } catch {
                    throw ('Failed to enable ''AutomaticManagedPagefile'' on ''{0}''. Reason: {1}' -f $driveLetter, $($Error[0].Exception.Message))
                }
            } else {
                return ('''AutomaticManagedPageFile'' is already enabled on ''{0}''. No changes were made.' -f $driveLetter)
            }
        }
        'Custom' {
            $pageFile = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($pageFile.AutomaticManagedPagefile -eq $true) {
                try {
                    $pageFile.AutomaticManagedPagefile = $false
                    Set-CimInstance -InputObject $pageFile -ErrorAction Stop
                } catch {
                    throw ('Failed to enable the Custom settings for the PageFile.sys on ''{0}''. Reason: {1}' -f $driveLetter, $($Error[0].Exception.Message))
                }
            }
            try {
                $pageFileLocation = '{0}\pagefile.sys' -f $driveLetter
                $pageFileSet = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction Stop | Where-Object { $_.name -eq $pageFileLocation }
                $pageFileSet.InitialSize = $initialSizeMB
                $pageFileSet.MaximumSize = $maximumSizeMB
                Set-CimInstance -InputObject $pageFileSet -ErrorAction Stop
                return 'Enabled ''Custom Setting'' for PageFile on ''{0}''. Initial size: {1} MB, Maximum size: {2} MB.' -f $driveLetter, $initialSizeMB, $maximumSizeMB
            } catch {
                throw ('Failed to enable the Custom settings for the PageFile.sys on ''{0}''. Reason: {1}' -f $driveLetter, $($Error[0].Exception.Message))
            }
        }
    }
    #endregion
} End {}