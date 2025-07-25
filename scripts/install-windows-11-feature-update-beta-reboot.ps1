<#
.SYNOPSIS
    Prepares and schedules a Windows 11 feature upgrade by performing compatibility checks and creating a scheduled task.

.DESCRIPTION
    This script orchestrates the Windows 11 upgrade process by verifying system requirements, downloading necessary components, and scheduling the actual upgrade to run as a background task. After validation, it creates a scheduled task that executes the upgrade script under SYSTEM context with a 15-second delay. The script exits immediately after scheduling, while the upgrade process continues in the background.
    The progress can be monitored by reviewing the log files located at: "C:\ProgramData\_Automation\Script\Install-Windows11FeatureUpdate"

.NOTES
    [script]
    name = "Template Script"
    description = "Prepares and schedules a Windows 11 feature upgrade by performing compatibility checks and creating a scheduled task."
    categories = ["ProVal", "Maintenance", "Patching"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

.FUNCTIONALITY
The script performs the following actions in sequence:

1. GLOBALS SETUP
   - Disables progress confirmation prompts
   - Enables TLS 1.2 security protocol

2. INITIAL VERIFICATION
   - Battery Check: Aborts if device is running on battery power
   - OS Version Check: Validates Windows 10/11 OS (aborts on unsupported OS)

3. VARIABLE INITIALIZATION
   - Defines working directories, URLs, and task names
   - Sets paths for script storage and compatibility checker

4. WORKING DIRECTORY SETUP
   - Cleans existing working directory
   - Creates new directory at $env:ProgramData\_Automation\Script\Install-Windows11FeatureUpdate
   - Grants 'Everyone' full control permissions

5. OS VERSION CHECK
   - Compares current OS build against Microsoft's latest Windows 11 build
   - Aborts if latest update is already installed
   - Proceeds if newer build is available

6. DRIVE SPACE VALIDATION
   - Verifies ≥64GB free space on system drive
   - Throws error with diagnostic link if check fails

7. HARDWARE COMPATIBILITY CHECK
   - Downloads Microsoft's HardwareReadiness.ps1 script
   - Executes compatibility assessment
   - Aborts if system is "NOT CAPABLE" (with results output)

8. UPGRADE SCRIPT DOWNLOAD
   - Fetches primary upgrade script from corporate repository
   - Saves to working directory as Install-Windows11FeatureUpdate.ps1

9. STORED STATE RESET
   - Ensures NuGet package provider is available
   - Updates/installs Strapper module
   - Resets execution tracking state via Write-StoredObject

10. TASK SCHEDULING
    - Creates scheduled task named "Initiate - Install-Windows11FeatureUpdate"
    - Configures task to run hidden PowerShell process with upgrade script
    - Triggers execution after 15-second delay under SYSTEM account
    - Outputs log location confirmation upon success


.EXAMPLE
    # Verify scheduled task creation
    Get-ScheduledTask -TaskName "Initiate - Install-Windows11FeatureUpdate" | Select-Object TaskName, State, Actions

.EXAMPLE
    # Monitor upgrade logs (after scheduling)
    Get-Content "C:\ProgramData\_Automation\Script\Install-Windows11FeatureUpdate\*.log" -Tail 20 -Wait

.OUTPUTS
    - C:\ProgramData\_Automation\Script\Install-Windows11FeatureUpdate\*.log
#>

begin {
    #region Globals
    $ProgressPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    #endRegion

    #region Initial Verification
    if ((Get-CimInstance -ClassName win32_battery).BatteryStatus -eq 1) {
        throw 'The Computer battery is not charging please plug in the charger.'
        exit 1
    }
    if ([System.Environment]::OSVersion.Version.Major -ne 10) {
        throw 'Unsupported Operating System. The script is designed to work for Windows 10 and Windows 11.'
        exit 1
    }
    #endRegion

    #region Variables
    $projectName = 'Install-Windows11FeatureUpdate'
    $workingDirectory = '{0}\_automation\script\{1}' -f $env:ProgramData, $projectName
    $baseUrl = 'https://file.provaltech.com/repo'
    $ps1Url = '{0}/script/{1}.ps1' -f $baseUrl, $projectName
    $ps1Path = '{0}\{1}.ps1' -f $workingDirectory, $projectName
    $taskName = 'Initiate - {0}' -f $projectName
    $osVersionCheckUrl = 'https://content.provaltech.com/attachments/windows-os-support.json'
    $compatibilityCheckScriptDownloadUrl = 'https://download.microsoft.com/download/e/1/e/e1e682c2-a2ee-46c7-ad1e-d0e38714a795/HardwareReadiness.ps1'
    $compatibilityCheckScriptPath = '{0}\HardwareReadiness.ps1' -f $workingDirectory
    $tableName = 'Windows11LatestFeatureUpdate'
    #endRegion
} process {
    #region Working Directory
    Remove-Item -Path $workingDirectory -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (!(Test-Path -Path $workingDirectory)) {
        try {
            New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            throw 'Failed to Create ''{0}''. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message)
            exit 1
        }
    }

    if (-not (((Get-Acl -Path $workingDirectory).Access | Where-Object { $_.IdentityReference -match 'EveryOne' }).FileSystemRights -match 'FullControl')) {
        $Acl = Get-Acl -Path $workingDirectory
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
        $Acl.AddAccessRule($AccessRule)
        Set-Acl -Path $workingDirectory -AclObject $Acl
    }
    #endRegion

    #region Check OS Version
    $iwr = Invoke-WebRequest -Uri $osVersionCheckUrl -UseBasicParsing
    $json = $iwr.content -replace "$([char]0x201C)|$([char]0x201D)", '"' -replace "$([char]0x2018)|$([char]0x2019)", '''' -replace '&#x2014;', ' ' -replace '&nbsp;', ''
    $rows = ($json | ConvertFrom-Json).rows
    $osVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Version
    $latestVersion = $rows | Where-Object { $_.BaseOS -eq 'Windows 11' -and [Version]$_.Build -gt [Version]$osVersion } | Sort-Object -Property Build -Descending | Select-Object -First 1
    if (!$latestVersion) {
        return 'Information: Latest available feature update ({0}) for windows 11 is installed.'
        exit 0
    } else {
        Write-Information ('Information: Latest available feature update for windows 11 is {0}' -f $latestVersion.Build) -InformationAction Continue
    }
    #endRegion

    #region Drive Space Check
    $systemVolume = Get-Volume -DriveLetter $env:SystemDrive[0]
    if ($systemVolume.SizeRemaining -le 64GB) {
        throw @"
Error: The Drive Space health check failed. The drive must have 64GB of free space to perform a Feature Update.
Current available space on $($env:SystemDrive[0]): $([math]::round($systemVolume.SizeRemaining / 1GB, 2))
For more information: https://learn.microsoft.com/en-us/troubleshoot/windows-client/deployment/windows-10-upgrade-quick-fixes?toc=%2Fwindows%2Fdeployment%2Ftoc.json&bc=%2Fwindows%2Fdeployment%2Fbreadcrumb%2Ftoc.json#verify-disk-space
"@
    }
    #endRegion

    #region Compatibility Check
    try {
        Invoke-WebRequest -Uri $compatibilityCheckScriptDownloadUrl -OutFile $compatibilityCheckScriptPath -UseBasicParsing -ErrorAction Stop
    } catch {
        throw 'Failed to download the compatibility check script from ''{0}''. Reason: {1}' -f $compatibilityCheckScriptDownloadUrl, $($Error[0].Exception.Message)
        exit 1
    }
    Unblock-File -Path $compatibilityCheckScriptPath -ErrorAction SilentlyContinue

    $compatibilityCheck = & $compatibilityCheckScriptPath
    $obj = $compatibilityCheck[1] | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($obj.returnResult -ne 'CAPABLE' -or $compatibilityCheck -match 'NOT CAPABLE') {
        throw @"
$Env:ComputerName is incompatible with windows 11 upgrade.
Result returned by Compatibility check script:
$compatibilityCheck
Minimum system requirements: https://www.microsoft.com/en-in/windows/windows-11-specifications
"@
        exit 1
    }
    #endRegion

    #region Download
    try {
        Invoke-WebRequest -Uri $ps1Url -OutFile $ps1Path -UseBasicParsing -ErrorAction Stop
    } catch {
        throw 'Failed to download the installer from ''{0}''. Reason: {1}' -f $ps1Url, $($Error[0].Exception.Message)
        exit 1
    }
    #endRegion

    #region reset StoredTableInfo
    Get-PackageProvider -Name NuGet -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    try {
        Update-Module -Name Strapper -ErrorAction Stop
    } catch {
        Install-Module -Name Strapper -Repository PSGallery -SkipPublisherCheck -Force
        Get-Module -Name Strapper -ListAvailable | Where-Object { $_.Version -ne (Get-InstalledModule -Name Strapper).Version } | ForEach-Object { Uninstall-Module -Name Strapper -MaximumVersion $_.Version }
    }
    (Import-Module -Name 'Strapper') 3>&1 2>&1 1>$null
    Set-StrapperEnvironment
    $storedData = @{
        PrimaryTaskExecuted = 0
    }
    $storedData | Write-StoredObject -TableName $tableName -Clobber -WarningAction SilentlyContinue -Depth 2 -ErrorAction SilentlyContinue
    #endregion

    #region Scheduled Task
    (Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }) | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    try {
        $action = New-ScheduledTaskAction -Execute 'cmd.exe' -WorkingDirectory $workingDirectory -Argument ('/c start /min "" Powershell -NoLogo -ExecutionPolicy Bypass -NoProfile -NonInteractive -Windowstyle Hidden -File "' + $ps1Path + '"')
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(15)
        $setting = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -RunLevel Highest
        $scheduledTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $setting -Principal $principal
        Register-ScheduledTask -TaskName $TaskName -InputObject $ScheduledTask -ErrorAction Stop | Out-Null
        return ('Task to run the primary script ''{1}'' has been scheduled. Detailed logs can be found at ''{0}''' -f $workingDirectory, $taskName)
    } catch {
        throw ('Failed to Schedule the task. Reason: {0}' -f ($Error[0].Exception.Message))
        exit 1
    }
    #endRegion
} end {}