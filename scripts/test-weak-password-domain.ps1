<#
.SYNOPSIS
    NinjaRMM implementation wrapper for the agnostic Test-WeakCredentials script that performs Active Directory password auditing with intelligent alerting and platform-specific data formatting.

.DESCRIPTION
    This script serves as a NinjaRMM-specific implementation wrapper for the agnostic PowerShell script "Test-WeakCredentials".
    The agnostic script performs the actual Active Directory password auditing, while this wrapper handles:
    - Platform-specific integration with NinjaRMM (custom fields, exit codes, compound conditions)
    - Data formatting and presentation in WYSIWYG custom fields
    - Intelligent comparison logic to prevent duplicate alerting
    - Script lifecycle management (download, execution, validation)

    ARCHITECTURE:
    This script does NOT perform the actual password auditing. Instead, it:
    1. Downloads the agnostic "Test-WeakCredentials.ps1" script from a remote repository
    2. Executes the agnostic script with appropriate parameters
    3. Processes and formats the results for NinjaRMM display
    4. Implements comparison logic to detect NEW issues (not previously reported)
    5. Returns exit codes that compound conditions monitor for ticket generation

    FUNCTIONALITY BREAKDOWN:

    1. PREREQUISITE VALIDATION:
       - Verifies the system has Primary Domain Controller (PDC) role (DomainRole = 5)
         * PDC role is required because Active Directory password data is only accessible on the PDC
         * Script terminates with exit code 0 if PDC role is not detected
       - Validates available disk space when "Large" dictionary size is selected
         * Large dictionary requires minimum 20 GB free space on system drive
         * Script terminates with exit code 2 if insufficient space is available

    2. WORKING DIRECTORY SETUP:
       - Creates working directory at: $env:ProgramData\_Automation\Script\Test-WeakCredentials
       - Configures directory permissions to grant "Everyone" FullControl with inheritance
       - This directory is used by the agnostic script for temporary files, logs, and data storage
       - The $workingPath variable is passed to the agnostic script for its working directory needs

    3. TLS SECURITY CONFIGURATION:
       - Configures .NET ServicePointManager to use TLS 1.3 and/or TLS 1.2 for secure HTTPS connections
       - Required for downloading the agnostic script from the remote repository
       - Falls back to available TLS versions if 1.3 is not supported
       - Provides warnings if TLS 1.2+ is unavailable (PowerShell 2.0/.NET 2.0 limitation)

    4. AGNOSTIC SCRIPT DOWNLOAD:
       - Downloads "Test-WeakCredentials.ps1" from: https://contentrepo.net/repo/script/Test-WeakCredentials.ps1
       - Saves to: $env:ProgramData\_Automation\Script\Test-WeakCredentials\Test-WeakCredentials.ps1
       - Uses existing local copy if download fails (allows offline execution with cached script)
       - Terminates with exit code 2 if download fails AND no local copy exists

    5. PARAMETER CONFIGURATION:
       - Builds parameter hash table for the agnostic script execution
       - Always sets Cleanup parameter to 'All' (ensures cleanup of temporary files after execution)
       - Reads passwordDictionarySize from NinjaRMM environment variable ($env:passwordDictionarySize)
       - Supported dictionary sizes: Tiny, Small, Medium, Large
       - Defaults to 'Tiny' if environment variable is not set
       - Passes parameters using PowerShell splatting to the agnostic script

    6. AGNOSTIC SCRIPT EXECUTION:
       - Executes the downloaded/cached Test-WeakCredentials.ps1 script with configured parameters
       - Captures the script's output object (contains audit results)
       - The agnostic script performs the actual password auditing:
         * Checks for weak passwords matching common dictionary patterns
         * Identifies duplicate passwords across multiple user accounts
         * Verifies domain security settings (reversible encryption, interactive logon messages)
         * Returns structured object with: WeakPasswords, DuplicatePasswords, ReversibleEncryptionState, InteractiveLogonMsgState

    7. EXECUTION VALIDATION:
       - Verifies successful execution by checking for log file existence
       - Log file expected at: $env:ProgramData\_Automation\Script\Test-WeakCredentials\Test-WeakCredentials-log.txt
       - Checks for error log file: Test-WeakCredentials-error.txt
       - If error log exists, extracts and displays error content
       - Terminates with exit code 2 if execution validation fails

    8. RESULT FORMATTING FOR NINJARMM:
       - Converts audit results into HTML table format for WYSIWYG custom field display
       - HTML-encodes all password values to prevent XSS and ensure proper display
       - Creates structured HTML table with columns:
         * Reversible Encryption State
         * Interactive Logon Message State
         * Duplicate Passwords (formatted as HTML list)
         * Weak Passwords (formatted as HTML list)
         * Data Collection Time (timestamp in yyyy-MM-dd HH:mm:ss format)
       - Replaces spaces with &nbsp; entities to preserve formatting in WYSIWYG editor
       - Writes formatted HTML to NinjaRMM custom field: 'cpvalWeakCredentialsAudit' (displayed as 'cPVAL Weak Credentials Audit')

    9. RESULT PERSISTENCE:
       - Uses Strapper module to store audit results in local database
       - Table name: 'WeakPasswordsAuditing'
       - Stores: WeakPasswords (comma-separated), DuplicatePasswords (comma-separated), DataCollectionTime
       - This persistent storage enables comparison with future scans to detect NEW issues

    10. INTELLIGENT ALERTING LOGIC (DUPLICATE PREVENTION):
        - Retrieves previously stored audit results from local database
        - Compares current scan results against previous results to identify NEW issues
        - Duplicate Password Comparison:
          * Parses previous duplicate passwords from comma-separated string
          * Compares each current duplicate against previous list
          * Sets $alerting = $true only if NEW duplicates are found
          * Logs informational messages about new vs. existing duplicates
        - Weak Password Comparison:
          * Parses previous weak passwords from comma-separated string
          * Compares each current weak password against previous list
          * Sets $alerting = $true only if NEW weak passwords are found
          * Logs informational messages about new vs. existing weak passwords
        - First Run Behavior:
          * If no previous results exist, all detected issues are considered "new"
          * Sets $alerting = $true for all issues on first execution
        - Prevents redundant alerting for issues already reported in previous scans

    11. EXIT CODE MANAGEMENT:
        - Exit Code 0: No new issues detected (or no issues exist)
          * Returned when $alerting remains $false
          * Compound condition will NOT generate tickets
        - Exit Code 1: New weak or duplicate passwords detected
          * Returned when $alerting is $true
          * Compound condition monitors this exit code and generates tickets
          * Includes informational message directing users to custom field for details
        - Exit Code 2: Script execution error
          * Returned for: PDC validation failure, insufficient disk space, download failures, execution validation failures
          * Indicates script could not complete successfully

    12. TICKET GENERATION (COMPOUND CONDITION):
        - This script does NOT generate tickets directly
        - The NinjaRMM compound condition that triggers this script monitors the exit code
        - When exit code 1 is returned, the compound condition generates tickets automatically
        - This separation allows for flexible alerting configuration in NinjaRMM without modifying the script

    CUSTOM FIELD OUTPUT:
    The script writes comprehensive audit results to the WYSIWYG custom field 'cPVAL Weak Credentials Audit' in tabular HTML format.
    This provides administrators with immediate visibility into:
    - Current security configuration state (reversible encryption, interactive logon messages)
    - All detected duplicate passwords (not just new ones)
    - All detected weak passwords (not just new ones)
    - Timestamp of data collection
    The custom field is updated on every execution, regardless of whether new issues are detected.

.PARAMETER None
    This script does not accept direct parameters. It uses NinjaRMM script runtime environment variables for configuration:

    - passwordDictionarySize (optional): Dictionary size for password checking
      * Valid values: Tiny, Small, Medium, Large
      * Default: Tiny (if not specified)
      * Large dictionary requires 20 GB free disk space
      * Larger dictionaries provide more comprehensive password checking but require more resources
      * Dictionary download sizes:
        - Tiny: 3MB
        - Small: 58MB
        - Medium: 253MB
        - Large: 2.9GB

.EXAMPLE
    .\Test-WeakADPasswordsNinjaRMMImp.ps1

    Executes the script with default settings (Tiny dictionary size, Cleanup='All').
    The script will download/use the agnostic Test-WeakCredentials script, execute it, format results,
    compare against previous scans, and return appropriate exit codes for compound condition monitoring.

.EXAMPLE
    # In NinjaRMM, set environment variable:
    # passwordDictionarySize = "Medium"
    .\Test-WeakADPasswordsNinjaRMMImp.ps1

    Executes with Medium dictionary size for more comprehensive password checking.

.REQUIREMENTS
    - Primary Domain Controller (PDC) role (DomainRole = 5)
    - Active Directory PowerShell module (required by agnostic script)
    - Strapper module (for local database storage and retrieval)
    - Internet connectivity (for initial script download, optional for subsequent runs)
    - Minimum 20 GB free space (if using Large dictionary size)
    - TLS 1.2 or 1.3 support (for script download)

.NOTES
    [script]
    name = "Test Weak Password [Domain]"
    description = "NinjaRMM implementation wrapper for the agnostic Test-WeakCredentials script that performs Active Directory password auditing with intelligent alerting and platform-specific data formatting."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "Password Dictionary Size"
    description = """
    Dictionary size for password checking.
    * Dictionary download sizes:
        - Tiny: 3MB
        - Small: 58MB
        - Medium: 253MB
        - Large: 2.9GB
    """
    type = "Drop-down"
    mandatory = false
    default_value = "Tiny"
    option_values = ["Tiny", "Small", "Medium", "Large"]
    top_option_is_default = true

.LINK
    - Test-WeakCredentials: https://contentrepo.net/repo/script/Test-WeakCredentials.ps1
    - 7za.exe: https://file.provaltech.com/repo/tools/7za.exe
    - TinyPasswordDictionary: https://download.weakpass.com/wordlists/1937/ignis-1M.txt.7z
    - SmallPasswordDictionary: http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2
    - MediumPasswordDictionary: https://download.weakpass.com/wordlists/1256/hk_hlm_founds.txt.gz
    - LargePasswordDictionary: https://download.weakpass.com/wordlists/1950/weakpass_3w.7z
#>

begin {
    #region globals
    # Configure PowerShell preferences to suppress progress, warnings, and confirmation prompts
    $ProgressPreference = 'SilentlyContinue'
    $WarningPreference = 'SilentlyContinue'
    $ConfirmPreference = 'None'
    #endRegion

    #region variables
    # Define project name, working directories, log paths, and script download URLs
    $projectName = 'Test-WeakCredentials'
    $workingDirectory = '{0}\_Automation\Script\{1}' -f $env:ProgramData, $projectName
    $scriptPath = '{0}\{1}.ps1' -f $workingDirectory, $projectName
    $logPath = '{0}\{1}-log.txt' -f $workingDirectory, $projectName
    $errorLogPath = '{0}\{1}-error.txt' -f $workingDirectory, $projectName
    $baseUrl = 'https://contentrepo.net/repo'
    $scriptUrl = '{0}/script/{1}.ps1' -f $baseUrl, $projectName
    $workingPath = $workingDirectory
    $customField = 'cpvalWeakCredentialsAudit'
    $customFieldLabel = 'cPVAL Weak Credentials Audit'
    $tableName = 'WeakPasswordsAuditing'
    $exitCode = 0
    $alerting = $false
    #endRegion

    #region rmm parameters hash table
    # Build parameter hash table from NinjaRMM environment variables for script execution
    $parameters = @{
        Cleanup = 'All'
    }

    $pwDictSize = $env:passwordDictionarySize
    if ($pwDictSize) {
        $parameters.Add('PWDictSize', $pwDictSize)
    } else {
        $parameters.Add('PWDictSize', 'Tiny')
    }
    #endRegion
} process {
    #region check is primary domain controller
    # Verify that this machine is a Primary Domain Controller (required for AD password auditing)
    $isPdc = (Get-CimInstance -Class Win32_ComputerSystem).DomainRole
    if ($isPdc -ne 5) {
        Write-Information -MessageData 'This system does not have the Primary Domain Controller role. The script requires PDC to access Active Directory password data. Terminating execution.' -InformationAction Continue
        return
    }
    #endRegion

    #region check free drive space if large dictionary is selected
    # Validate available disk space when using the Large dictionary option (requires 20GB minimum)
    if ($parameters.PWDictSize -eq 'Large') {
        $freeSpace = [Math]::Round((Get-Volume -DriveLetter $env:SystemDrive.TrimEnd(':')).SizeRemaining / 1GB)
        if ($freeSpace -lt 20) {
            Write-Information -MessageData ('The Large password dictionary option requires a minimum of 20 GB of free space on the system drive. Current available space: {0} GB. Terminating execution.' -f $freeSpace) -InformationAction Continue
            $exitCode = 2
            return
        }
    }
    #endRegion

    #region working directory
    # Create and configure the working directory with appropriate permissions for script execution
    if (!(Test-Path -Path $workingDirectory)) {
        try {
            New-Item -Path $workingDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Information -MessageData ('Unable to create the working directory at {0}. Error details: {1}' -f $workingDirectory, $($Error[0].Exception.Message)) -InformationAction Continue
            $exitCode = 2
            return
        }
    }

    $acl = Get-Acl -Path $workingDirectory
    $hasFullControl = $acl.Access | Where-Object {
        $_.IdentityReference -match 'Everyone' -and $_.FileSystemRights -match 'FullControl'
    }
    if (-not $hasFullControl) {
        $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule(
            'Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
        )
        $acl.AddAccessRule($accessRule)
        Set-Acl -Path $workingDirectory -AclObject $acl -ErrorAction SilentlyContinue
    }
    #endRegion

    #region set tls policy
    # Configure TLS security protocol to support secure HTTPS connections for script download
    $supportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
    if (($supportedTLSversions -contains 'Tls13') -and ($supportedTLSversions -contains 'Tls12')) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
    } elseif ($supportedTLSversions -contains 'Tls12') {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    } else {
        Write-Information -MessageData 'TLS 1.2 and TLS 1.3 are not available on this system. The script download operation may encounter connection failures.' -InformationAction Continue
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Write-Information -MessageData 'PowerShell version 2 and .NET Framework 2.0 do not provide support for TLS 1.2 protocol.' -InformationAction Continue
        }
    }
    #endRegion

    #region download script
    # Download the password auditing script from the remote repository, or use existing local copy if available
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    } catch {
        if (!(Test-Path -Path $scriptPath)) {
            Write-Information -MessageData ('The script download from {0} was unsuccessful, and no local script file was found at {1}. Error: {2}' -f $scriptUrl, $scriptPath, $($Error[0].Exception.Message)) -InformationAction Continue
            $exitCode = 2
            return
        }
    }
    #endRegion

    #region execute script
    # Execute the downloaded password auditing script with configured parameters and capture results
    $myResults = if ($parameters) {
        & $scriptPath @parameters
    } else {
        & $scriptPath
    }
    #endRegion

    #region result parsing
    $duplicatePasswords = @()

    foreach ($duplicatePassword in $myResults.duplicatePasswords) {
        $duplicatePasswords += $duplicatePassword -join '; '
    }

    $newResults = [PSCustomObject]@{
        ReversibleEncryptionState = $myResults.ReversibleEncryptionState
        InteractiveLogonMsgState  = $myResults.InteractiveLogonMsgState
        DuplicatePasswords        = $duplicatePasswords
        WeakPasswords             = $myResults.WeakPasswords
    }
    #endRegion

    #region log verification
    # Verify that the password auditing script executed successfully by checking for log files and errors
    if (!(Test-Path -Path $logPath )) {
        Write-Information -MessageData ('The password auditing script at {0} did not complete successfully. The execution may have been blocked by security software or encountered a fatal error.' -f $scriptPath) -InformationAction Continue
        $exitCode = 2
        return
    }
    if ((Test-Path -Path $errorLogPath)) {
        $content = Get-Content -Path $logPath
        $logContent = $content[$($($content.IndexOf($($content -match ('{0}$' -f $projectName))[-1])) + 1)..$($content.length - 1)]
        Write-Information -MessageData ('Error log content: {0}' -f ($logContent | Out-String)) -InformationAction Continue
        $exitCode = 2
        return
    }
    #endRegion

    #region convert results
    # Convert password audit results into HTML format for display in NinjaRMM custom fields
    if ($newResults.DuplicatePasswords -and $newResults.DuplicatePasswords.Count -gt 0) {
        $duplicatePasswordsHtml = '<ul style=''margin: 0; padding-left: 20px;''>'
        foreach ($password in $newResults.DuplicatePasswords) {
            $duplicatePasswordsHtml += ('<li>{0}</li>' -f $password)
        }
        $duplicatePasswordsHtml += '</ul>'
    } else {
        $duplicatePasswordsHtml = ''
    }


    if ($newResults.WeakPasswords -and $newResults.WeakPasswords.Count -gt 0) {
        $weakPasswordsHtml = '<ul style=''margin: 0; padding-left: 20px;''>'
        foreach ($password in $newResults.WeakPasswords) {
            $weakPasswordsHtml += ('<li>{0}</li>' -f $password)
        }
        $weakPasswordsHtml += '</ul>'
    } else {
        $weakPasswordsHtml = ''
    }

    $dataCollectionTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    $customFieldValue = @"
<table style='border-collapse: collapse; width: 100%; font-family: sans-serif;'>
    <thead>
        <tr>
            <th style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; text-align: left; background-color: #4CAF50; color: #ffffff;'>Reversible Encryption State</th>
            <th style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; text-align: left; background-color: #4CAF50; color: #ffffff;'>Interactive Logon Message State</th>
            <th style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; text-align: left; background-color: #4CAF50; color: #ffffff;'>Duplicate Passwords</th>
            <th style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; text-align: left; background-color: #4CAF50; color: #ffffff;'>Weak Passwords</th>
            <th style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; text-align: left; background-color: #4CAF50; color: #ffffff;'>Data Collection Time</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; background-color: #f2f2f2;'>$($newResults.ReversibleEncryptionState)</td>
            <td style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; background-color: #f2f2f2;'>$($newResults.InteractiveLogonMsgState)</td>
            <td style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; background-color: #f2f2f2;'>$duplicatePasswordsHtml</td>
            <td style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; background-color: #f2f2f2;'>$weakPasswordsHtml</td>
            <td style='border-width: 1px; border-style: solid; border-color: #ddd; padding: 12px; background-color: #f2f2f2;'>$dataCollectionTime</td>
        </tr>
    </tbody>
</table>
"@
    #endRegion

    #region set custom field
    # Update the NinjaRMM device custom field with the formatted HTML audit results
    # Remove the non-breaking space character
    $customFieldValue = $customFieldValue -replace ' ', '&nbsp;'
    Ninja-Property-Set -Name $customField -Value $customFieldValue
    #endRegion

    #region store duplicate and weak passwords
    # Store current audit results in local database for comparison with future scans to prevent duplicate alerts
    Import-Module -Name Strapper -ErrorAction SilentlyContinue
    $existingInfo = try { Get-StoredObject -TableName $tableName } catch { $null }
    $currentInfo = @{
        WeakPasswords      = if ($newResults.WeakPasswords) { $newResults.WeakPasswords -join ',' } else { $null }
        DuplicatePasswords = if ($newResults.DuplicatePasswords) { $newResults.DuplicatePasswords -join ',' } else { $null }
        DataCollectionTime = $dataCollectionTime
    }
    $currentInfo | Write-StoredObject -TableName $tableName -Depth 10 -ErrorAction SilentlyContinue -Clobber
    #endRegion

    #region compare duplicate passwords with the existing ones
    # Compare current duplicate password results against previous scan to identify only new issues for alerting
    if ($currentInfo.DuplicatePasswords) {
        if ($existingInfo) {
            $existingDuplicatePasswords = $existingInfo.DuplicatePasswords
            if ($existingDuplicatePasswords) {
                $previousDuplicatePasswords = $existingInfo.DuplicatePasswords.Trim() -replace '\s{0,},\s{0,}', ',' -split ',' |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    ForEach-Object { $_.Trim() }
                $newDuplicatePasswords = $newResults.DuplicatePasswords |
                    Where-Object { -not ($previousDuplicatePasswords -contains $_) }
                if ($newDuplicatePasswords) {
                    Write-Information -MessageData ('{0} new duplicate password(s) have been identified since the last scan on {1}. New duplicates: {2}{3}' -f $newDuplicatePasswords.Count, $existingInfo.DataCollectionTime, [Environment]::NewLine, ($newDuplicatePasswords | Out-String)) -InformationAction Continue
                    $alerting = $true
                } else {
                    Write-Information -MessageData ('No new duplicate passwords have been detected since the previous scan on {0}. All current duplicates were already reported.' -f $existingInfo.DataCollectionTime) -InformationAction Continue
                }
            } else {
                Write-Information -MessageData ('{0} duplicate password(s) detected during this scan. Details: {1}{2}' -f $newResults.DuplicatePasswords.Count, [Environment]::NewLine, ($newResults.DuplicatePasswords | Out-String)) -InformationAction Continue
                $alerting = $true
            }
        } else {
            Write-Information -MessageData ('{0} duplicate password(s) detected during this scan. Details: {1}{2}' -f $newResults.DuplicatePasswords.Count, [Environment]::NewLine, ($newResults.DuplicatePasswords | Out-String)) -InformationAction Continue
            $alerting = $true
        }
    } else {
        Write-Information -MessageData 'No duplicate passwords were found during this audit scan.' -InformationAction Continue
    }
    #endRegion

    #region compare weak passwords with the existing ones
    # Compare current weak password results against previous scan to identify only new issues for alerting
    if ($currentInfo.WeakPasswords) {
        if ($existingInfo) {
            $existingWeakPasswords = $existingInfo.WeakPasswords
            if ($existingWeakPasswords) {
                $previousWeakPasswords = $existingInfo.WeakPasswords.Trim() -replace '\s{0,},\s{0,}', ',' -split ',' |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    ForEach-Object { $_.Trim() }
                $newWeakPasswords = $newResults.WeakPasswords |
                    Where-Object { -not ($previousWeakPasswords -contains $_) }
                if ($newWeakPasswords) {
                    Write-Information -MessageData ('{0} new weak password(s) have been identified since the last scan on {1}. New weak passwords: {2}{3}' -f $newWeakPasswords.Count, $existingInfo.DataCollectionTime, [Environment]::NewLine, ($newWeakPasswords | Out-String)) -InformationAction Continue
                    $alerting = $true
                } else {
                    Write-Information -MessageData ('No new weak passwords have been detected since the previous scan on {0}. All current weak passwords were already reported.' -f $existingInfo.DataCollectionTime) -InformationAction Continue
                }
            } else {
                Write-Information -MessageData ('{0} weak password(s) detected during this scan. Details: {1}{2}' -f $newResults.WeakPasswords.Count, [Environment]::NewLine, ($newResults.WeakPasswords | Out-String)) -InformationAction Continue
                $alerting = $true
            }
        } else {
            Write-Information -MessageData ('{0} weak password(s) detected during this scan. Details: {1}{2}' -f $newResults.WeakPasswords.Count, [Environment]::NewLine, ($newResults.WeakPasswords | Out-String)) -InformationAction Continue
            $alerting = $true
        }
    } else {
        Write-Information -MessageData 'No weak passwords were found during this audit scan.' -InformationAction Continue
    }
    #endRegion

    #region set exit code
    # Set exit code to 1 when new issues are detected, which triggers ticket generation in NinjaRMM compound conditions
    if ($alerting) {
        Write-Information -MessageData ('Additional audit details and results are available in the device custom field: {0}' -f $customFieldLabel) -InformationAction Continue
        $exitCode = 1
        return
    }
    #endRegion
} end {
    exit $exitCode
}