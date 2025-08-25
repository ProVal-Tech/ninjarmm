<#
.SYNOPSIS
#requires -RunAsAdministrator
#requires -Version 5.1
This script automates health checks, self-healing, and conditional service restarts for Active Directory Domain Controllers. It helps administrators quickly identify and remediate AD issues, ensuring domain controller reliability and service continuity.
It depends on the agnostic script "Test-ADHealthAndRepair".
https://content.provaltech.com/docs/f2c09601-b391-449b-9380-c022f1829eda/

.DESCRIPTION
This script automates health checks, self-healing, and conditional service restarts for Active Directory Domain Controllers. It performs the following tasks:

- Checks if the host is a Domain Controller.
- Initializes required modules and environment settings.
- Tracks and stores the last script run time for event log queries.
- Performs AD health checks using dcdiag, repadmin /replsummary, and repadmin /showrepl.
- Queries Windows event logs for recent critical or error events in DNS Server and Directory Service logs.
- Logs all findings and outcomes.
- If issues are detected and self-healing is enabled, runs remediation steps:
    - Synchronizes AD replication.
    - Flushes DNS resolver cache.
    - Reregisters DNS records.
    - Updates domain controller DNS registration.
- If issues are detected and Self-Heal is enabled, restarts all or selected AD-related services as specified by parameters.
- Logs the outcome of each service restart and remediation step.
- Updates and stores the script run time for future audits.

.NOTES
    [script]
    name = "Test AD Health and Repair"
    description = "This script automates health checks, self-healing, and conditional service restarts for Active Directory Domain Controllers. It helps administrators quickly identify and remedy AD issues, ensuring domain controller reliability and service continuity."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "SelfHeal"
    description = "Initiates self-healing actions if AD issues are detected. Leave it blank to disable self-healing for the AD health issue fix, or set any value, such as 1, to enable the self-healing feature."
    type = "String/Text"
    mandatory = false
    default_value = ""
  

    [[script.variables]]
    name = "RestartAllADService"
    description = "Restarts all core AD-related services if issues are detected and SelfHeal is enabled. Leave it blank for no action, or set it to 1 to allow all AD services to restart. Note: The SelfHeal parameter must be enabled for this feature to operate."
    type = "String/Text"
    mandatory = false
    default_value = ""
    

    [[script.variables]]
    name = "ServicesToRestart"
    description = "Specify one or more AD-related services to restart if issues are detected and SelfHeal is enabled. Ex: DNS, Netlogon. Note: The SelfHeal parameter must be enabled for this feature to operate."
    type = "String/Text"
    mandatory = false
    default_value = ""
   
#>

# Begin block: Initialization and setup
Begin {
    #region Variables - Configure script environment and define constants
    # Suppress progress bars for cleaner output in automated environments
    $ProgressPreference = 'SilentlyContinue'
    # Disable confirmation prompts to allow unattended execution
    $ConfirmPreference = 'None'
    # Enforce TLS 1.2 for secure network communications
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

    # Define core script parameters
    $projectName = 'Test-ADHealthAndRepair'  # Base name for project-related files
    $workingDirectory = 'C:\ProgramData\_automation\Script\{0}' -f $projectName  # Centralized working directory
    $scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName  # Full path to installation script
    $scriptDownloadUrl = 'https://file.provaltech.com/repo/script/Test-ADHealthAndRepair.ps1'  # Official 
    $scriptlog = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
    $scripterrorlog = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
    #endRegion

    #region workingDirectory - Prepare clean execution environment
    # Remove existing directory to prevent file conflicts
    Remove-Item -Path $workingDirectory -Recurse -Force -ErrorAction SilentlyContinue

    # Create fresh working directory with error handling
    if (-not (Test-Path $WorkingDirectory)) {
        try {
            New-Item -Path $WorkingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        catch {
            throw "An error occurred: Failed to Create $WorkingDirectory. Reason: $($Error[0].Exception.Message)"
        }
    }

    # Ensure full permissions for automated operations
    if (-not ( ( ( Get-Acl $WorkingDirectory ).Access | Where-Object { $_.IdentityReference -Match 'EveryOne' } ).FileSystemRights -Match 'FullControl' )) {
        $Acl = Get-Acl $WorkingDirectory
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
        $Acl.AddAccessRule($AccessRule)
        Set-Acl $WorkingDirectory $Acl -ErrorAction SilentlyContinue
    }
    #endRegion

    if (-not [string]::IsNullOrEmpty($env:selfheal)) {
        $selfhealcheck = $env:selfheal  # Prefer runtime environment variable
    } 
    if (-not [string]::IsNullOrEmpty($env:servicestorestart)) {
        $ServicesToRestartCheck = $env:servicestorestart
    }
    if (-not [string]::IsNullOrEmpty($env:restartalladservice)) {
        $RestartAllADServiceCheck = $env:restartalladservice
    }
    #endRegion
}

# Process block: Execute the downloaded script with the specified parameters

Process {
    $role = (Get-CimInstance Win32_ComputerSystem).DomainRole

    if ($role -ne 4 -and $role -ne 5) {
        return "This machine is NOT a Domain Controller. Exiting script."
    }
    else {
        Write-Output "This machine IS a Domain Controller. Continuing..."
        
        #Download Script
        $response = Invoke-WebRequest -Uri $scriptDownloadUrl -UseBasicParsing
        if (($response.StatusCode -ne 200) -and (!(Test-Path -Path $scriptPath))) {
            return "An error occurred: No pre-downloaded script exists and the script '$PS1URL' failed to download. Exiting."
        }
        elseif ($response.StatusCode -eq 200) {
            Remove-Item -Path $scriptPath -ErrorAction SilentlyContinue
			Remove-Item -Path $scriptlog -ErrorAction SilentlyContinue
			Remove-Item -Path $scripterrorlog -ErrorAction SilentlyContinue
            [System.IO.File]::WriteAllLines($scriptPath, $response.Content)
        }
        if (!(Test-Path -Path $scriptPath)) {
            return 'An error occurred: The script could not be downloaded. Exiting.'
        }
        #EndRegion
        #region Execution Logic
        if ([string]::IsNullOrEmpty($SelfhealCheck) -and [string]::IsNullOrEmpty($RestartAllADServiceCheck) -and [string]::IsNullOrEmpty($ServicesToRestartCheck)) {
            # No parameters set
            & $scriptPath *> $null
            Write-Output "To see full details, check the log file at: $scriptlog"
            Get-Content -Path $scriptlog | Select-Object -Last 50
        }
        elseif (-not [string]::IsNullOrEmpty($SelfhealCheck) -and [string]::IsNullOrEmpty($RestartAllADServiceCheck) -and [string]::IsNullOrEmpty($ServicesToRestartCheck)) {
            # Only SelfHealCheck
            & $scriptPath -SelfHeal *> $null
            Write-Output "To see full details, check the log file at: $scriptlog"
            Get-Content -Path $scriptlog | Select-Object -Last 50
        }
        elseif (-not [string]::IsNullOrEmpty($SelfhealCheck) -and -not [string]::IsNullOrEmpty($RestartAllADServiceCheck)) {
            # SelfHealCheck and RestartAllADServiceCheck
            & $scriptPath -SelfHeal -RestartAllADService *> $null
            Write-Output "To see full details, check the log file at: $scriptlog"
            Get-Content -Path $scriptlog | Select-Object -Last 50
        }
        elseif (-not [string]::IsNullOrEmpty($SelfhealCheck) -and -not [string]::IsNullOrEmpty($ServicesToRestartCheck)) {
            # SelfHealCheck and specific services
            $services = $ServicesToRestartCheck -split ',' | ForEach-Object { $_.Trim() }
            & $scriptPath -SelfHeal -ServicesToRestart $services *> $null
            Write-Output "To see full details, check the log file at: $scriptlog"
            Get-Content -Path $scriptlog | Select-Object -Last 50
        }
        else {
            return 'An error occurred: Invalid combination of parameters provided.'
        }
        #endregion
    }
}
# End block: Final cleanup or additional actions (if needed)
End {}