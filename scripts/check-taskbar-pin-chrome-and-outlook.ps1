<#
.SYNOPSIS
    Validates that only Google Chrome and New Outlook are pinned to the Windows taskbar for the currently logged-in user.

.DESCRIPTION
    This script automates the validation of taskbar pinning for Google Chrome and New Outlook. It performs the following steps:
        - Checks if the operating system is a client version (not server).
        - Verifies that Google Chrome and New Outlook are installed.
        - Prepares a working directory and sets permissions for script execution.
        - Removes any existing log and validation files.
        - Generates a secondary PowerShell script that:
            - Checks for the existence of the Chrome shortcut in the pinned taskbar folder.
            - Ensures only one shortcut (.lnk) exists in the pinned folder.
            - Validates the LayoutModification.xml file for correct taskbar pin configuration.
            - Confirms only Chrome and New Outlook are present in the TaskbarPinList.
            - Logs all actions and errors, and creates a validation file on success.
        - Writes the secondary script to disk.
        - Schedules the secondary script to run via a scheduled task with elevated privileges.
        - Waits for the scheduled task to complete and checks for the validation file.
        - Reads the log file for errors and outputs the result.
        - Cleans up the scheduled task after execution.

    The use of a scheduled task ensures the script can perform privileged operations (such as reading taskbar layout files) even in environments with UAC or permission restrictions.
    All actions and errors are logged for troubleshooting, and the script exits with code 0 on success or 1 if any error occurs or validation fails.

.EXAMPLE
    .\Check-TaskbarPinChromeAndOutlook.ps1
    Validates that only Google Chrome and New Outlook are pinned to the taskbar for the current user.

.NOTES
    [script]
    name = "Check Taskbar Pin Chrome and Outlook"
    description = "Validates that only Google Chrome and New Outlook are pinned to the Windows taskbar for the currently logged-in user. This action is restricted to Windows Workstation systems only."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

#region Global Variables
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'
$InformationPreference = 'Continue'
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
#endRegion

#region Check OS Product Type
$osProductType = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).ProductType
if ($osProductType -ne 1) {
    Write-Information 'This script is intended to run on client OS only. Exiting...'
    exit 0
}
#endRegion

#region application check
$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
$uninstallInfo = Get-ChildItem $uninstallPaths -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -match [Regex]::Escape('Google Chrome') }
if (!($uninstallInfo)) {
    Write-Information 'Google Chrome is not installed. Exiting...'
    exit 0
}

$newOutlookInfo = Get-AppxPackage -Name 'Microsoft.OutlookforWindows' -AllUsers -ErrorAction SilentlyContinue
if (!($newOutlookInfo)) {
    Write-Information 'New Outlook is not installed. Exiting...'
    exit 0
}
#endRegion

#region Variables
$projectName = 'Check-TaskbarPinChromeAndOutlook'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
$logFilePath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$validationFile = '{0}\ValidationFile.txt' -f $workingDirectory
$taskName = 'Scheduled Task - {0}' -f $projectName
#endRegion

#region Logged In User Check
$loggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
if ([string]::IsNullOrEmpty($loggedInUser)) {
    Write-Information 'No user is currently logged in. Exiting...'
    exit 0
}
#endRegion

#region Working Directory
if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Information ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
        exit 0
    }
}

if (-not (((Get-Acl -Path $workingDirectory).Access | Where-Object { $_.IdentityReference -match 'EveryOne' }).FileSystemRights -match 'FullControl')) {
    $acl = Get-Acl -Path $workingDirectory
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
    $acl.AddAccessRule($AccessRule)
    Set-Acl -Path $workingDirectory -AclObject $acl
}
#endRegion

#region Remove Existing Log File
Remove-Item -Path $logFilePath -Force -ErrorAction SilentlyContinue | Out-Null
#endRegion

#region Remove Validation File
Remove-Item -Path $validationFile -Force -ErrorAction SilentlyContinue | Out-Null
#endRegion

#region Script Content
<#
.SYNOPSIS
    Orchestrates the validation that only Google Chrome and New Outlook are pinned to the Windows taskbar for the currently logged-in user.

.DESCRIPTION
    This primary script performs the following steps:
        - Checks if the operating system is a client version (not server).
        - Verifies that Google Chrome and New Outlook are installed.
        - Prepares a working directory and sets permissions for script execution.
        - Removes any existing log and validation files.
        - Generates a secondary PowerShell script that:
            - Checks for the Chrome shortcut in the pinned taskbar folder.
            - Ensures only one shortcut (.lnk) exists in the pinned folder.
            - Validates the LayoutModification.xml file for correct taskbar pin configuration.
            - Confirms only Chrome and New Outlook are present in the TaskbarPinList.
            - Logs all actions and errors, and creates a validation file on success.
        - Writes the secondary script to disk.
        - Schedules the secondary script to run via a scheduled task with elevated privileges.
        - Waits for the scheduled task to complete and checks for the validation file.
        - Reads the log file for errors and outputs the result.
        - Cleans up the scheduled task after execution.

    The use of a scheduled task ensures the script can perform privileged operations (such as reading taskbar layout files) even in environments with UAC or permission restrictions.
    All actions and errors are logged for troubleshooting, and the script exits with code 0 on success or 1 if any error occurs or validation fails.

.EXAMPLE
    .\Check-TaskbarPinChromeAndOutlook.ps1
    Validates that only Google Chrome and New Outlook are pinned to the taskbar for the current user.

.NOTES
    - Requires administrative privileges to schedule tasks and access taskbar layout files.
    - Tested on Windows 10/11.
    - Uses scheduled tasks to bypass permission/UAC issues for taskbar validation.
    - All actions and errors are logged for troubleshooting.
    - The script will exit with code 0 on success, or 1 if any error occurs or validation fails.
#>
$scriptContent = @'
#region Global Variables
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'
$InformationPreference = 'Continue'
#endRegion

#region Variables
$projectName = 'Check-TaskbarPinChromeAndOutlook'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$logFilePath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$validationFile = '{0}\ValidationFile.txt' -f $workingDirectory
$shortCutDirectory = '{0}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar' -f $env:APPDATA
$pinnedXmlPath = '{0}\Microsoft\Windows\Shell\LayoutModification.xml' -f $env:LOCALAPPDATA
$chromeShortCutPath = '{0}\Chrome.lnk' -f $shortCutDirectory
#endRegion

#region Write Log Function
function Write-LogFile {
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Path to the log file')]
        [string]$LogFilePath,
        [Parameter(Mandatory = $true, HelpMessage = 'Text to log')]
        [string]$Text,
        [Parameter(Mandatory = $false, HelpMessage = 'Log level')]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = '{0} [{1}] {2}' -f $timestamp, $Level, $Text
    Add-Content -Path $LogFilePath -Value $logEntry -Encoding UTF8
}
#endRegion

#region Create Validation File Function
function Create-ValidationFile {
    Write-LogFile -LogFilePath $logFilePath -Text ('Creating validation file at {0}' -f $validationFile) -Level 'Information'
    try {
        New-Item -Path $validationFile -ItemType File -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-LogFile -LogFilePath $logFilePath -Text ('Failed to create validation file at {0}. Reason: {1}' -f $validationFile, $($Error[0].Exception.Message)) -Level 'Error'
        return 0
    }
}
#endRegion

#region Check Chrome Shortcut
Write-LogFile -LogFilePath $logFilePath -Text ('Checking for Chrome shortcut at {0}' -f $chromeShortCutPath) -Level 'Information'
if (!(Test-Path -Path $chromeShortCutPath)) {
    Write-LogFile -LogFilePath $logFilePath -Text ('Chrome shortcut not found at {0}.' -f $chromeShortCutPath) -Level 'Error'
    Create-ValidationFile
    return 1
}
#endRegion

#region Check Shortcut Directory Content
Write-LogFile -LogFilePath $logFilePath -Text ('Checking for shortcut directory content at {0}' -f $shortCutDirectory) -Level 'Information'
$shortCutFiles = (Get-ChildItem -Path $shortCutDirectory -Recurse -Filter '*.lnk' | Where-Object { $_.Name -notmatch '^Chrome' }).Name
if ($shortCutFiles.Count -ge 1) {
    Write-LogFile -LogFilePath $logFilePath -Text ('More than one shortcut found in {0}. Found: {1}' -f $shortCutDirectory, ($shortCutFiles -join ', ')) -Level 'Error'
    Create-ValidationFile
    return 1
}
#endRegion

#region Check LayoutModification File Content
Write-LogFile -LogFilePath $logFilePath -Text ('Checking for LayoutModification.xml at {0}' -f $pinnedXmlPath) -Level 'Information'

[xml]$layoutContent = Get-Content -Path $pinnedXmlPath -ErrorAction SilentlyContinue
if (!($layoutContent)) {
    Write-LogFile -LogFilePath $logFilePath -Text ('LayoutModification.xml not found or is empty at {0}.' -f $pinnedXmlPath) -Level 'Error'
    Create-ValidationFile
    return 1
}

$taskbarPinList = $layoutContent.LayoutModificationTemplate.CustomTaskbarLayoutCollection.TaskbarLayout.TaskbarPinList
$taskbarPinnedItems = ($taskbarPinList | Get-Member -MemberType Property).Name
if ($taskbarPinnedItems.Count -gt 2) {
    Write-LogFile -LogFilePath $logFilePath -Text ('More than two items found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, ($taskbarPinnedItems -join ', ')) -Level 'Error'
    Create-ValidationFile
    return 1
} elseif ($taskbarPinnedItems.Count -lt 2) {
    Write-LogFile -LogFilePath $logFilePath -Text ('Less than two items found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, ($taskbarPinnedItems -join ', ')) -Level 'Error'
    Create-ValidationFile
    return 1
}

$uwaApp = $taskbarPinList.UWA.AppUserModelID

if ($uwaApp.Count -gt 1) {
    Write-LogFile -LogFilePath $logFilePath -Text ('More than one UWA AppUserModelID found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, ($uwaApp -join ', ')) -Level 'Error'
    Create-ValidationFile
    return 1
} elseif ($uwaApp.Count -lt 1) {
    Write-LogFile -LogFilePath $logFilePath -Text ('No UWA AppUserModelID found in TaskbarPinList in {0}.' -f $pinnedXmlPath) -Level 'Error'
    Create-ValidationFile
    return 1
} elseif ($uwaApp -ne 'Microsoft.OutlookForWindows_8wekyb3d8bbwe!Microsoft.OutlookforWindows') {
    Write-LogFile -LogFilePath $logFilePath -Text ('Unexpected UWA AppUserModelID found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, $uwaApp) -Level 'Error'
    Create-ValidationFile
    return 1
}

$desktopApp = $taskbarPinList.DesktopApp.DesktopApplicationLinkPath

if ($desktopApp.Count -gt 1) {
    Write-LogFile -LogFilePath $logFilePath -Text ('More than one DesktopApp found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, ($desktopApp -join ', ')) -Level 'Error'
    Create-ValidationFile
    return 1
} elseif ($desktopApp.Count -lt 1) {
    Write-LogFile -LogFilePath $logFilePath -Text ('No DesktopApp found in TaskbarPinList in {0}.' -f $pinnedXmlPath) -Level 'Error'
    Create-ValidationFile
    return 1
} elseif ($desktopApp -ne $chromeShortCutPath) {
    Write-LogFile -LogFilePath $logFilePath -Text ('Unexpected DesktopApp found in TaskbarPinList in {0}. Found: {1}' -f $pinnedXmlPath, $desktopApp) -Level 'Error'
    Create-ValidationFile
    return 1
}

Write-LogFile -LogFilePath $logFilePath -Text ('Only Chrome and New Outlook shortcuts found in TaskbarPinList in {0}.' -f $pinnedXmlPath) -Level 'Information'
#endRegion

#region Create Validation File
Create-ValidationFile
#endRegion
'@
#endRegion

#region Write Script File
try {
    [System.IO.File]::WriteAllText($scriptPath, $scriptContent, $utf8NoBomEncoding)
} catch {
    Write-Information ('Failed to write script file. Reason: {0}' -f $($Error[0].Exception.Message))
    exit 0
}
#endRegion

#region Scheduled Task
Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName } | Unregister-ScheduledTask -Confirm:$False -ErrorAction SilentlyContinue | Out-Null
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -WorkingDirectory $WorkingDirectory -Argument  ('/c start /min "" Powershell' + ' -NoLogo -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden' + " -File ""$($scriptPath)""")
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
$setting = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
$principal = New-ScheduledTaskPrincipal -GroupId ((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')).Translate([System.Security.Principal.NTAccount]).Value) -RunLevel Highest
$scheduledTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $setting -Principal $principal
try {
    Register-ScheduledTask -TaskName $taskName -InputObject $scheduledTask -ErrorAction Stop | Out-Null
    Write-Information ('Successfully created the scheduled task ''{0}''' -f $taskName)
} catch {
    Write-Information ('Failed to Schedule the task. Reason: {0}' -f $($Error[0].Exception.Message))
    exit 0
}
#endRegion

#region confirm scheduled task execution
Start-Sleep -Seconds 7
$taskRunTime = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue).LastRunTime
if ($taskRunTime) {
    Write-Information ('Task Initiated at: {0}' -f $taskRunTime)
} else {
    Write-Information 'Initiating the task'
    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}
#endRegion

#region Validation
$timeout = 300
$slept = 0
for ($slept = 0; $slept -lt $timeout; $slept += 5) {
    if (!(Test-Path -Path $validationFile)) {
        Start-Sleep -Seconds 5
    } else {
        break
    }
}
$logContent = Get-Content -Path $logFilePath -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName } | Unregister-ScheduledTask -Confirm:$False -ErrorAction SilentlyContinue | Out-Null
if ($slept -ge $timeout) {
    Write-Information ('Script is running for more than {0} seconds. Validation file not found at {1}' -f $timeout, $validationFile)
    Write-Information ('Log Content: {0}' -f ($logContent | Out-String))
    exit 0
} else {
    Write-Information 'Script Completed.'
    Write-Information ('Validation File Path: {0}' -f $validationFile)
    Write-Information ('Log Content: {0}' -f ($logContent | Out-String))
    if ($logContent -match [regex]::Escape('[Error]')) {
        exit 1
    }
    exit 0
}
#endRegion