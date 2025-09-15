<#
.SYNOPSIS
    Pins Google Chrome and New Outlook to the Windows taskbar for the currently logged-in user.

.DESCRIPTION
    This script automates the process of pinning Google Chrome and the New Outlook app to the Windows taskbar.
    It performs application checks to ensure both Google Chrome and New Outlook are installed.
    The script prepares a working directory and sets permissions, removes any existing log and validation files, and generates a PowerShell script that:
        - Creates a shortcut for Google Chrome in the user's pinned taskbar folder.
        - Generates a LayoutModification.xml file to define the desired taskbar layout (pinning Chrome and Outlook).
        - Removes existing shortcuts and registry properties related to taskbar pins.
        - Copies the XML layout file to the appropriate location.
        - Restarts the Explorer process to apply the new taskbar layout.
        - Creates a validation file to confirm completion.
        - Logs all actions and errors to a log file.

    The main script writes this generated script to disk and schedules it to run via a scheduled task with elevated privileges.
    It waits for the scheduled task to complete, checks for the validation file, and reads the log file for errors.
    If the process fails or times out, it outputs the log content and exits with code 1; otherwise, it confirms success and exits with code 0.

    This approach ensures that taskbar pinning works reliably even in environments with UAC or permission restrictions.

.EXAMPLE
    .\Pin-ChromeAndOutlook.ps1
    Pins Google Chrome and New Outlook to the taskbar for the current user.

.NOTES
    [script]
    name = "Pin Chrome and Outlook to Taskbar"
    description = "Pins Google Chrome and the New Outlook to the Windows taskbar for the currently logged-in user, while removing all other pinned items. This action is restricted to Windows Workstation systems only."
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
$projectName = 'Pin-ChromeAndOutlookToTaskbar'
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
        exit 1
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
    Pins Google Chrome and New Outlook to the Windows taskbar for the currently logged-in user.

.DESCRIPTION
    This script is the primary orchestrator for automating the pinning of Google Chrome and New Outlook to the Windows taskbar.
    It performs the following steps:
        - Checks if Google Chrome and New Outlook are installed.
        - Prepares a working directory and sets permissions.
        - Removes any existing log and validation files.
        - Generates a secondary PowerShell script that handles shortcut creation, XML layout generation, registry cleanup, and Explorer restart.
        - Writes the secondary script to disk.
        - Schedules the secondary script to run via a scheduled task with elevated privileges.
        - Waits for the scheduled task to complete and checks for a validation file.
        - Reads the log file for errors and outputs the result.
        - Cleans up the scheduled task after execution.

    The use of a scheduled task ensures the script can perform privileged operations (such as modifying taskbar layout and restarting Explorer) even in environments with UAC or permission restrictions.
    All actions and errors are logged for troubleshooting, and the script exits with code 0 on success or 1 if any error occurs or validation fails.

.EXAMPLE
    .\Pin-ChromeAndOutlook.ps1
    Pins Google Chrome and New Outlook to the taskbar for the current user.

.NOTES
    - Requires administrative privileges to schedule tasks and modify taskbar layout.
    - Tested on Windows 10/11.
    - Uses scheduled tasks to bypass permission/UAC issues for taskbar modification.
    - All actions and errors are logged for troubleshooting.
    - The script will exit with code 0 on success, or 1 if any error occurs or validation fails.

#>

$scriptContent = @'
#region Global Variables
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'
$InformationPreference = 'Continue'
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
#endRegion

#region Variables
$projectName = 'Pin-ChromeAndOutlookToTaskbar'
$workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
$logFilePath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
$xmlPath = '{0}\LayoutModification.xml' -f $workingDirectory, $projectName
$validationFile = '{0}\ValidationFile.txt' -f $workingDirectory
$shortCutDirectory = '{0}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar' -f $env:APPDATA
$shortCutRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
$pinnedXmlPath = '{0}\Microsoft\Windows\Shell\LayoutModification.xml' -f $env:LOCALAPPDATA
$chromePotentialPath = @(
    ('{0}\Google\Chrome\Application\chrome.exe' -f ${env:ProgramFiles(x86)}),
    ('{0}\Google\Chrome\Application\chrome.exe' -f $env:ProgramFiles)
)
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
        return 1
    }
}
#endRegion

#region Create Shortcut function
function Create-Shortcut {
    [CmdletBinding()]
    param (
        [string]$TargetPath,
        [string]$ShortcutPath
    )
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Save()
}
#endRegion

#region Xml Content
$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
Version="1">

<CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
        <taskbar:TaskbarPinList>
            <taskbar:UWA AppUserModelID="Microsoft.OutlookForWindows_8wekyb3d8bbwe!Microsoft.OutlookforWindows" />
            <taskbar:DesktopApp DesktopApplicationLinkPath="$chromeShortCutPath"/>
        </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
</CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
#endRegion

#region Write Xml File
Write-LogFile -LogFilePath $logFilePath -Text ('Writing XML content to {0}' -f $xmlPath) -Level 'Information'
try {
    [System.IO.File]::WriteAllText($xmlPath, $xmlContent, $utf8NoBomEncoding)
} catch {
    if (!(Test-Path -Path $xmlPath)) {
        Write-LogFile -LogFilePath $logFilePath -Text ('Failed to create XML file at {0}' -f $xmlPath) -Level 'Error'
        Create-ValidationFile
        return 1
    }
}
#endRegion

#region Remove Existing Shortcuts
Write-LogFile -LogFilePath $logFilePath -Text 'Removing existing shortcuts if any' -Level 'Information'
try {
    Get-ChildItem -Path $shortCutDirectory -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction Stop | Out-Null
} catch {
    Write-LogFile -LogFilePath $logFilePath -Text ('Failed to remove existing shortcuts from {0}. Reason: {1}' -f $shortCutDirectory, $($Error[0].Exception.Message)) -Level 'Warning'
}
#endRegion

#region Create Shortcut Directory if not exists
if (!(Test-Path -Path $shortCutDirectory)) {
    try {
        New-Item -Path $shortCutDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-LogFile -LogFilePath $logFilePath -Text ('Failed to Create shortcut directory {0}. Reason: {1}' -f $shortCutDirectory, $($Error[0].Exception.Message)) -Level 'Error'
        Create-ValidationFile
        return 1
    }
}
#endRegion

#region Remove Existing Registry Key
if (Test-Path -Path $shortCutRegistryPath) {
    foreach ($existingProperty in (Get-ItemProperty -Path $shortCutRegistryPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notmatch '^PS' }).Name) {
        try {
            Remove-ItemProperty -Path $shortCutRegistryPath -Name $existingProperty -ErrorAction Stop | Out-Null
            Write-LogFile -LogFilePath $logFilePath -Text ('Removed existing registry property {0} from {1}' -f $existingProperty, $shortCutRegistryPath) -Level 'Information'
        } catch {
            Write-LogFile -LogFilePath $logFilePath -Text ('Failed to remove existing registry property {0} from {1}. Reason: {2}' -f $existingProperty, $shortCutRegistryPath, $($Error[0].Exception.Message)) -Level 'Warning'
        }
    }
}
#endRegion

#region Create Google Chrome Shortcut
$chromePath = foreach ($path in $chromePotentialPath) {
    if (Test-Path -Path $path) {
        $path
        break
    }
}
Write-LogFile -LogFilePath $logFilePath -Text ('Google Chrome path: {0}' -f $chromePath) -Level 'Information'

Write-LogFile -LogFilePath $logFilePath -Text ('Creating Google Chrome shortcut at {0}' -f $chromeShortCutPath) -Level 'Information'

try {
    Create-Shortcut -TargetPath $chromePath -ShortcutPath $chromeShortCutPath -ErrorAction Stop
} catch {
    if (!(Test-Path -Path $chromeShortCutPath)) {
        Write-LogFile -LogFilePath $logFilePath -Text ('Failed to create Google Chrome shortcut at {0}' -f $chromeShortCutPath) -Level 'Error'
        Create-ValidationFile
        return 1
    }
}
#endRegion

#region Place Xml File in Pinned Location
Write-LogFile -LogFilePath $logFilePath -Text ('Placing XML file to {0}' -f $pinnedXmlPath) -Level 'Information'
try {
    Copy-Item -Path $xmlPath -Destination $pinnedXmlPath -Force -ErrorAction Stop | Out-Null
} catch {
    Write-LogFile -LogFilePath $logFilePath -Text ('Failed to copy XML file to {0}' -f $pinnedXmlPath) -Level 'Error'
    Create-ValidationFile
    return 1
}
#endRegion

#region Restart Explorer
Write-LogFile -LogFilePath $logFilePath -Text 'Restarting Explorer process' -Level 'Information'
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 2
Start-Process -FilePath 'explorer.exe' -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 5
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
    exit 1
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
    exit 1
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
    exit 1
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
