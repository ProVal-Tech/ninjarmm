<#
.SYNOPSIS
    Completely uninstalls the NinjaRMM (NinjaOne) Agent and Ninja Remote components from a Windows system, including services, processes, files, directories, drivers, printers, and registry entries. The script also schedules itself to run with SYSTEM privileges and cleans up after execution.

.DESCRIPTION
    This script is designed to thoroughly remove all traces of the NinjaRMM (NinjaOne) Agent and Ninja Remote from a Windows machine. It performs the following actions:

    1. **Privilege Escalation**: Checks if the script is running as Administrator. If not, it relaunches itself with elevated privileges.

    2. **Logging**: Starts a transcript to log all actions and outputs to a file in the Windows temp directory.

    3. **Uninstall NinjaRMM Agent**:
        - Locates the NinjaRMM Agent installation path via registry or service.
        - Retrieves the MSI uninstall string and runs the uninstaller silently.
        - Stops and deletes related services and processes.
        - Removes installation and data directories.
        - Cleans up all related registry keys, including those from previous or corrupt installs.
        - Identifies and warns about orphaned registry keys that may indicate a corrupt install.

    4. **Uninstall Ninja Remote**:
        - Stops and deletes the Ninja Remote process and service.
        - Removes the Ninja Remote virtual display driver using `pnputil`.
        - Deletes the Ninja Remote installation directory.
        - Removes related registry entries for all user profiles (both loaded and unloaded), including scheduled loading/unloading of user hives as needed.
        - Removes the Ninja Remote printer and its driver files.

    5. **Script Generation and Scheduling**:
        - Writes the removal script to disk in a dedicated working directory.
        - Installs/updates the `Strapper` PowerShell module to assist with environment setup.
        - Schedules the script to run as a SYSTEM task using Windows Task Scheduler, ensuring it runs with the highest privileges and in a hidden window.
        - Schedules a secondary task to remove the primary scheduled task after one hour, ensuring cleanup of scheduled tasks.

    6. **Error Handling and Reporting**:
        - Tracks and logs any failures during execution.
        - Outputs a summary of failures or a success message at the end.
        - Exits with appropriate status code (0 for success, 1 for failure).

.PARAMETER None
    All variables are defined within the script; no parameters are required.

.NOTES
  [Script]
    name = "Uninstall NinjaOne Agent"
    description = "Downloads and schedules a script to remove the NinjaOne Agent and Ninja Remote using a scheduled task. Schedules a secondary task to clean up the scheduled task after an hour."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>
# Using a Scheduled task to run the uninstaller script as it stop the processes to uninstall the agent
begin {
    #region Globals
    $ProgressPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    #endRegion

    #region Variables
    $failureCount = 0
    $failures = @()
    $projectName = 'NinjaOneAgentRemoval'
    $workingDirectory = 'C:\ProgramData\_automation\script\{0}' -f $projectName
    $ps1Path = '{0}\{1}.ps1' -f $workingDirectory, $projectName
    $ps1Content = @'
#Get current user context
$CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
#Check user that is running the script is a member of Administrator Group
if (!($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))) {
  #UAC Prompt will occur for the user to input Administrator credentials and relaunch the powershell session
  Write-Output 'This script must be ran with administrative privileges'
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; Exit
}

$Now = Get-Date -Format 'dd-MM-yyyy_HHmmss'
$LogPath = "$env:windir\temp\NinjaRemoval_$Now.txt"
Start-Transcript -Path $LogPath -Force
$ErrorActionPreference = 'SilentlyContinue'
function Uninstall-NinjaMSI {
  $Arguments = @(
    "/x$($UninstallString)"
    '/quiet'
    '/L*V'
    'C:\windows\temp\NinjaRMMAgent_uninstall.log'
    "WRAPPED_ARGUMENTS=`"--mode unattended`""
  )

  Start-Process "$NinjaInstallLocation\NinjaRMMAgent.exe" -ArgumentList "-disableUninstallPrevention NOUI"
  Start-Sleep 10
  Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow
  Write-Output 'Finished running uninstaller. Continuing to clean up...'
  Start-Sleep 30
}

$NinjaRegPath = 'HKLM:\SOFTWARE\WOW6432Node\NinjaRMM LLC\NinjaRMMAgent'
$NinjaDataDirectory = "$($env:ProgramData)\NinjaRMMAgent"
$UninstallRegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'

Write-Output 'Beginning NinjaRMM Agent removal...'

if (!([System.Environment]::Is64BitOperatingSystem)) {
  $NinjaRegPath = 'HKLM:\SOFTWARE\NinjaRMM LLC\NinjaRMMAgent'
  $UninstallRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
}

$NinjaInstallLocation = (Get-ItemPropertyValue $NinjaRegPath -Name Location).Replace('/', '\') 

if (!(Test-Path "$($NinjaInstallLocation)\NinjaRMMAgent.exe")) {
  $NinjaServicePath = ((Get-Service | Where-Object { $_.Name -eq 'NinjaRMMAgent' }).BinaryPathName).Trim('"')
  if (!(Test-Path $NinjaServicePath)) {
    Write-Output 'Unable to locate Ninja installation path. Continuing with cleanup...'
  }
  else {
    $NinjaInstallLocation = $NinjaServicePath | Split-Path
  }
}

$UninstallString = (Get-ItemProperty $UninstallRegPath | Where-Object { ($_.DisplayName -eq 'NinjaRMMAgent') -and ($_.UninstallString -match 'msiexec') }).UninstallString

if (!($UninstallString)) {
  Write-Output 'Unable to to determine uninstall string. Continuing with cleanup...' 
}
else {
  $UninstallString = $UninstallString.Split('X')[1]
  Uninstall-NinjaMSI
}

$NinjaServices = @('NinjaRMMAgent', 'nmsmanager', 'lockhart')
$Processes = @("NinjaRMMAgent", "NinjaRMMAgentPatcher", "njbar", "NinjaRMMProxyProcess64")


foreach ($Process in $Processes) {
  Get-Process $Process | Stop-Process -Force 
}

foreach ($NS in $NinjaServices) {
  if (($NS -eq 'lockhart') -and !(Test-Path "$NinjaInstallLocation\lockhart\bin\lockhart.exe")) {
    continue
  }
  if (Get-Service $NS) {
    & sc.exe DELETE $NS
    Start-Sleep 2
    if (Get-Service $NS) {
      Write-Output "Failed to remove service: $($NS). Continuing with removal attempt..."
    }
  }
}

if (Test-Path $NinjaInstallLocation) {
  Remove-Item $NinjaInstallLocation -Recurse -Force
  if (Test-Path $NinjaInstallLocation) {
    Write-Output 'Failed to remove Ninja Installation Directory:'
    Write-Output "$NinjaInstallLocation"
    Write-Output 'Continuing with removal attempt...'
  } 
}

if (Test-Path $NinjaDataDirectory) {
  Remove-Item $NinjaDataDirectory -Recurse -Force
  if (Test-Path $NinjaDataDirectory) {
    Write-Output 'Failed to remove Ninja Data Directory:'
    Write-Output "$NinjaDataDirectory"
    Write-Output 'Continuing with removal attempt...'
  }
}

$MSIWrapperReg = 'HKLM:\SOFTWARE\WOW6432Node\EXEMSI.COM\MSI Wrapper\Installed'
$ProductInstallerReg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products'
$HKCRInstallerReg = 'Registry::\HKEY_CLASSES_ROOT\Installer\Products'

$RegKeysToRemove = [System.Collections.Generic.List[object]]::New()

(Get-ItemProperty $UninstallRegPath | Where-Object { $_.DisplayName -eq 'NinjaRMMAgent' }).PSPath | ForEach-Object { $RegKeysToRemove.Add($_) }
(Get-ItemProperty $ProductInstallerReg | Where-Object { $_.ProductName -eq 'NinjaRMMAgent' }).PSPath | ForEach-Object { $RegKeysToRemove.Add($_) }
(Get-ChildItem $MSIWrapperReg | Where-Object { $_.Name -match 'NinjaRMMAgent' }).PSPAth | ForEach-Object { $RegKeysToRemove.Add($_) }
Get-ChildItem $HKCRInstallerReg | ForEach-Object { if ((Get-ItemPropertyValue $_.PSPath -Name 'ProductName') -eq 'NinjaRMMAgent') { $RegKeysToRemove.Add($_.PSPath) } }

$ProductInstallerKeys = Get-ChildItem $ProductInstallerReg | Select-Object *
foreach ($Key in $ProductInstallerKeys) {
  $KeyName = $($Key.Name).Replace('HKEY_LOCAL_MACHINE', 'HKLM:') + "\InstallProperties"
  if (Get-ItemProperty $KeyName | Where-Object { $_.DisplayName -eq 'NinjaRMMAgent' }) {
    $RegKeysToRemove.Add($Key.PSPath)
  }
}

Write-Output 'Removing registry items if found...'
foreach ($RegKey in $RegKeysToRemove) {
  if (!([string]::IsNullOrEmpty($RegKey))) {
    Write-Output "Removing: $($RegKey)"
    Remove-Item $RegKey -Recurse -Force
  }
}

if (Test-Path $NinjaRegPath) {
  Get-Item ($NinjaRegPath | Split-Path) | Remove-Item -Recurse -Force
  Write-Output "Removing: $($NinjaRegPath)"
}

foreach ($RegKey in $RegKeysToRemove) {
  if (!([string]::IsNullOrEmpty($RegKey))) {
    if (Test-Path $RegKey) {
      Write-Output 'Failed to remove the following registry key:'
      Write-Output "$($RegKey)"
    }
  }   
}

if (Test-Path $NinjaRegPath) {
  Write-Output "$NinjaRegPath"
}

#Checks for rogue reg entry from older installations where ProductName was missing
#Filters out a Windows Common GUID that doesn't have a ProductName
$Child = Get-ChildItem 'HKLM:\Software\Classes\Installer\Products'
$MissingPNs = [System.Collections.Generic.List[object]]::New()

foreach ($C in $Child) {
  if ($C.Name -match '99E80CA9B0328e74791254777B1F42AE') {
    continue
  }
  try {
    Get-ItemPropertyValue $C.PSPath -Name 'ProductName' -ErrorAction Stop | Out-Null
  }
  catch {
    $MissingPNs.Add($($C.Name))
  } 
}

if ($MissingPNs) {
  Write-Output 'Some registry keys are missing the Product Name.'
  Write-Output 'This could be an indicator of a corrupt Ninja install key.'
  Write-Output 'If you are still unable to install the Ninja Agent after running this script...'
  Write-Output 'Please make a backup of the following keys before removing them from the registry:'
  Write-Output ( $MissingPNs | Out-String )
}

##Begin Ninja Remote Removal##
$NR = 'ncstreamer'

if (Get-Process $NR -ErrorAction SilentlyContinue) {
   Write-Output 'Stopping Ninja Remote process...'
    try {
        Get-Process $NR | Stop-Process -Force
    }
    catch {
       Write-Output 'Unable to stop the Ninja Remote process...'
       Write-Output "$($_.Exception)"
       Write-Output 'Continuing to Ninja Remote service...'
    }
}

if (Get-Service $NR -ErrorAction SilentlyContinue) {
    try {
        Stop-Service $NR -Force
    }
    catch {
       Write-Output 'Unable to stop the Ninja Remote service...'
       Write-Output "$($_.Exception)"
       Write-Output 'Attempting to remove service...'
    }

    & sc.exe DELETE $NR
    Start-Sleep 5
    if (Get-Service $NR -ErrorAction SilentlyContinue) {
       Write-Output 'Failed to remove Ninja Remote service. Continuing with remaining removal steps...'
    }
}

$NRDriver = 'nrvirtualdisplay.inf'
$DriverCheck = pnputil /enum-drivers | Where-Object { $_ -match "$NRDriver" }
if ($DriverCheck) {
   Write-Output 'Ninja Remote Virtual Driver found. Removing...'
    $DriverBreakdown = pnputil /enum-drivers | Where-Object { $_ -ne 'Microsoft PnP Utility' }

    $DriversArray = [System.Collections.Generic.List[object]]::New()
    $CurrentDriver = @{}

    foreach ($Line in $DriverBreakdown) {
        if ($Line -ne "") {
            $ObjectName = $Line.Split(':').Trim()[0]
            $ObjectValue = $Line.Split(':').Trim()[1]
            $CurrentDriver[$ObjectName] = $ObjectValue
        }
        else {
            if ($CurrentDriver.Count -gt 0) {
                $DriversArray.Add([PSCustomObject]$CurrentDriver)
                $CurrentDriver = @{}
            }
        }
    }

    $DriverToRemove = ($DriversArray | Where-Object {$_.'Provider Name' -eq 'NinjaOne'}).'Published Name'
    pnputil /delete-driver "$DriverToRemove" /force
}

$NRDirectory = "$($env:ProgramFiles)\NinjaRemote"
if (Test-Path $NRDirectory) {
   Write-Output "Removing directory: $NRDirectory"
    Remove-Item $NRDirectory -Recurse -Force
    if (Test-Path $NRDirectory) {
       Write-Output 'Failed to completely remove Ninja Remote directory at:'
       Write-Output "$NRDirectory"
       Write-Output 'Continuing to registry removal...'
    }
}

$NRHKUReg = 'Registry::\HKEY_USERS\S-1-5-18\Software\NinjaRMM LLC'
if (Test-Path $NRHKUReg) {
    Remove-Item $NRHKUReg -Recurse -Force
}

function Remove-NRRegistryItems {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SID
    )
    $NRRunReg = "Registry::\HKEY_USERS\$SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $NRRegLocation = "Registry::\HKEY_USERS\$SID\Software\NinjaRMM LLC"
    if (Test-Path $NRRunReg) {
        $RunRegValues = Get-ItemProperty -Path $NRRunReg
        $PropertyNames = $RunRegValues.PSObject.Properties | Where-Object { $_.Name -match "NinjaRMM|NinjaOne" } 
        foreach ($PName in $PropertyNames) {    
           Write-Output "Removing item..."
           Write-Output "$($PName.Name): $($PName.Value)"
            Remove-ItemProperty $NRRunReg -Name $PName.Name -Force
        }
    }
    if (Test-Path $NRRegLocation) {
       Write-Output "Removing $NRRegLocation..."
        Remove-Item $NRRegLocation -Recurse -Force
    }
   Write-Output 'Registry removal completed.'
}

$AllProfiles = Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, Loaded, Special | 
Where-Object { $_.SID -like "S-1-5-21-*" }
$Mounted = $AllProfiles | Where-Object { $_.Loaded -eq $true }
$Unmounted = $AllProfiles | Where-Object { $_.Loaded -eq $false }

$Mounted | Foreach-Object {
   Write-Output "Removing registry items for $LocalPath"
    Remove-NRRegistryItems -SID "$($_.SID)"
}

$Unmounted | ForEach-Object {
    $Hive = "$($_.LocalPath)\NTUSER.DAT"
    if (Test-Path $Hive) {
        Write-Output "Loading hive and removing Ninja Remote registry items for $($_.LocalPath)..."

        REG LOAD HKU\$($_.SID) $Hive 2>&1>$null

        Remove-NRRegistryItems -SID "$($_.SID)"

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()

        REG UNLOAD HKU\$($_.SID) 2>&1>$null
    }
}

$NRPrinter = Get-Printer | Where-Object { $_.Name -eq 'NinjaRemote' }

if ($NRPrinter) {
   Write-Output 'Removing Ninja Remote printer...'
    Remove-Printer -InputObject $NRPrinter
}

$NRPrintDriverPath = "$env:SystemDrive\Users\Public\Documents\NrSpool\NrPdfPrint"
if (Test-Path $NRPrintDriverPath) {
   Write-Output 'Removing Ninja Remote printer driver...'
    Remove-Item $NRPrintDriverPath -Force
}

Write-Host 'Removal of Ninja Remote complete.'
##End Ninja Remote Removal##

Write-Output 'Removal script completed. Please review if any errors displayed.'
Stop-Transcript
'@
    #endregion
} process {
    #region Uninstall Ninja Remote
    Get-PackageProvider -Name NuGet -ForceBootstrap -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

    try {
        Update-Module -Name Strapper -ErrorAction Stop
    } catch {
        Install-Module -Name Strapper -Repository PSGallery -SkipPublisherCheck -Force
        Get-Module -Name Strapper -ListAvailable |
            Where-Object { $_.Version -ne (Get-InstalledModule -Name Strapper).Version } |
            ForEach-Object { Uninstall-Module -Name Strapper -MaximumVersion $_.Version }
    }

    (Import-Module -Name 'Strapper') 3>&1 2>&1 1>$null
    Set-StrapperEnvironment

    $installLocation = (Get-UserRegistryKeyProperty -Path 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Ninja Remote' -Name InstallLocation -WarningAction SilentlyContinue -ErrorAction SilentlyContinue).Value

    if ($installLocation) {
        try {
            foreach ($location in $installLocation) {
                if (Test-Path -Path $location) {
                    Remove-Item -Path $location -Force -Recurse -Confirm:$false -ErrorAction Stop
                }
            }
            Remove-UserRegistryItem -Path 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Ninja Remote' -Recurse -ErrorAction Stop
        } catch {
            Write-Output ('Failed to remove Ninja Remote. Reason: {0}' -f $Error[0].Exception.Message)
            $failureCount += 1
            $failures += ('Failed to remove Ninja Remote. Reason: {0}' -f $Error[0].Exception.Message)
        }
    }
    #endregion

    #region Working Directory
    if (!(Test-Path -Path $workingDirectory)) {
    try {
        New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        throw ('Failed to Create working directory {0}. Reason: {1}' -f $workingDirectory, $($Error[0].Exception.Message))
    }
    }

    if (-not (((Get-Acl -Path $workingDirectory).Access | Where-Object { $_.IdentityReference -match 'EveryOne' }).FileSystemRights -match 'FullControl')) {
        $acl = Get-Acl -Path $workingDirectory
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
        $acl.AddAccessRule($AccessRule)
        Set-Acl -Path $workingDirectory -AclObject $acl
    }
    #endRegion

    #region Write Script
    try {
        $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($ps1Path, $ps1Content, $utf8NoBomEncoding)
    } catch {
        Write-Output ('Failed to write the NinjaOneAgentRemoval script.Reason: {0}' -f $Error[0].Exception.Message)
        $failureCount += 1
        $failures += ('Failed to write the NinjaOneAgentRemoval script. Reason: {0}' -f $Error[0].Exception.Message)
    }
    #endRegion

    #region Primary Task
    $taskName = 'Initiate-{0}' -f $projectName
    Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    $Action = New-ScheduledTaskAction -Execute 'cmd.exe' -WorkingDirectory $workingDirectory -Argument ('/c start /min "" Powershell' + ' -NoLogo -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden' + " -File ""$($ps1Path)""")
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
    $setting = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -RunLevel Highest
    $ScheduledTask = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $setting -Principal $principal
    try {
        Register-ScheduledTask -TaskName $TaskName -InputObject $ScheduledTask -ErrorAction Stop | Out-Null
        Write-Output ('Successfully created the scheduled task ''{0}'' to uninstall NinjaOne Agent.' -f $TaskName)
    } catch {
        Write-Output ('Failed to schedule the task for NinjaOne Agent uninstallation. Reason: {0}.' -f $($Error[0].Exception.Message))
        $failureCount += 1
        $failures += ('Failed to schedule the task for NinjaOne Agent uninstallation. Reason: {0}.' -f $($Error[0].Exception.Message))
    }
    #endRegion

    #region Secondary Task
    # Secondary task will remove the primary task after an hour
    $secondaryTaskName = 'Remove-{0}' -f $taskName
    Get-ScheduledTask -TaskName $secondaryTaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    $command = @"
Get-ScheduledTask -TaskName $taskName | Unregister-ScheduledTask -Confirm:`$false -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName $secondaryTaskName | Unregister-ScheduledTask -Confirm:`$false -ErrorAction SilentlyContinue
"@
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $encodedString = [Convert]::ToBase64String($bytes)
    $Action = New-ScheduledTaskAction -Execute 'cmd.exe' -WorkingDirectory $workingDirectory -Argument ('/c start /min "" Powershell' + ' -NoLogo -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden' + " -EncodedCommand ""$($encodedString)""")
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(3600)
    $setting = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -RunLevel Highest
    $ScheduledTask = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $setting -Principal $principal
    try {
      Register-ScheduledTask -TaskName $secondaryTaskName -InputObject $ScheduledTask -ErrorAction Stop | Out-Null
    } catch {
        Write-Output ('Failed to schedule the secondary task {1}. Reason: {0}.' -f $($Error[0].Exception.Message), $secondaryTaskName)
        $failureCount += 1
        $failures += ('Failed to schedule the secondary task {1}. Reason: {0}.' -f $($Error[0].Exception.Message), $secondaryTaskName)
    }
    #endRegion
} end {
    #region Validation
    if ($failureCount -ge 1) {
        Write-Output ('Failures detected: {0}' -f ($failures | Out-String))
        exit 1
    } else {
        Write-Output 'Script completed successfully.'
        exit 0
    }
    #endRegion
}