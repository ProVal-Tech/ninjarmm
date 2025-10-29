<#
.SYNOPSIS
Checks for recent Domain Admin account lockouts in the last 15 minutes.

.DESCRIPTION
This script monitors the Security log for recent account lockouts (Event ID 4740), checks if any Domain Admin accounts are affected, outputs detailed info about the locked accounts, if any Domain Admin is locked out in last 15 minutes. This retrieves and outputs detailed information including the username, last login time, lockout time, endpoint, and domain.

.Usage
  - Exit code 1 indicates that one or more Domain Admin accounts have been locked out
  - Outputs detailed information about the locked-out accounts for further investigation

.NOTES
    [script]
    name = "Domain Admin Account Lockouts"
    description = "This script monitors the Security log for recent account lockouts (Event ID 4740), checks if any Domain Admin accounts are affected, outputs detailed info about the locked accounts, if any Domain Admin is locked out in last 15 minutes. This retrieves and outputs detailed information including the username, last login time, lockout time, endpoint, and domain."
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
#endRegion


# Set the start time to 15 minutes ago
$st = (Get-Date).AddMinutes(-15)

# Get account lockout events from Security log
$r = Get-WinEvent -ErrorAction SilentlyContinue -FilterHashtable @{
    LogName = 'Security'; 
    Id = 4740; 
    StartTime = $st 
} | ForEach-Object {
    $ex = ([xml]$_.ToXml()).Event
    $e = [ordered]@{EventDate = [DateTime]$ex.System.TimeCreated.SystemTime }
    $ex.EventData.ChildNodes | ForEach-Object { $e[$_.Name] = $_.'#text' }
    [PsCustomObject]$e
}

if ($r) {
    # Get all Domain Admin accounts
    $domainAdmins = Get-ADGroupMember -Identity 'Domain Admins' -Recursive | Select-Object -ExpandProperty SamAccountName

    # Filter lockouts for Domain Admins
    $lockedOutAdmins = $r | Where-Object { $domainAdmins -contains $_.TargetUserName }

    if ($lockedOutAdmins) {
        # Output detailed information
        $lockedOutAdmins | ForEach-Object {
            $user = $_.TargetUserName
            $lastLogin = (Get-ADUser -Identity $user -Properties LastLogonDate).LastLogonDate
            $lockoutTime = $_.EventDate
            $endpoint = $_.TargetDomainName
            $domain = $_.SubjectDomainName

            [PSCustomObject]@{
                Username = $user
                LastLogin = $lastLogin
                LockoutTime = $lockoutTime
                Endpoint = $endpoint
                Domain = $domain
            }
        } | Format-List

        exit 1
      
    }
}
