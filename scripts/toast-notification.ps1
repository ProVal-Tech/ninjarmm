<#
.SYNOPSIS
    NinjaRMM implementation of the agnostic script Invoke-ToastNotification to create and manage toast notifications with customizable options, including images, buttons, and scenarios for different use cases.
.NOTES
    [script]
    name = "Toast Notification"
    description = "NinjaRMM implementation of the agnostic script Invoke-ToastNotification to create and manage toast notifications with customizable options, including images, buttons, and scenarios for different use cases."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "NotificationType"
    description = "The type of notification to send. It is a mandatory variable."
    type = "Drop-Down"
    mandatory = true
    option_values = ["Generic", "PendingRebootUptime", "PendingRebootCheck", "ADPasswordExpiration"]
    top_option_is_default = false

    [[script.RebootButton]]
    name = "RebootButton"
    description = "Select RebootButton to enable the Reboot button in the notification. Unselecting the variable will disable it. RebootButton is available for Generic, PendingRebootUptime, and PendingRebootCheck notification types."
    type = "CheckBox"
    default_value = ""

    [[script.RunScriptButtonText]]
    name = "RunScriptButtonText"
    description = "Set the string in this variable to add a custom button with the name set in this variable to run a specified PowerShell script when clicked."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.ScriptPath]]
    name = "ScriptPath"
    description = "Full path to a PowerShell script (.ps1) to execute when the custom button is clicked. This must be a valid path ending in .ps1. Setting this variable is mandatory if RunScriptButtonText is set.
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.ScriptContext]]
    name = "ScriptContext"
    description = "The context in which the script runs. This can be 'User' or 'System'."
    type = "Drop-Down"
    mandatory = false
    option_values = ["User", "System"]
    top_option_is_default = false

    [[script.LearnMoreUrl]]
    name = "LearnMoreUrl"
    description = "URL to learn more about the notification. If this variable is set, a 'Learn More' button will be added to the notification."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.HideDismissButton]]
    name = "HideDismissButton"
    description = "Select to remove the Dismiss button from the notification. Dismiss button is added to the notification by default."
    type = "CheckBox"
    default_value = ""

    [[script.DismissButtonText]]
    name = "DismissButtonText"
    description = "Set the string in the DismissButtonText variable to customize the dismiss button's text. Leave it blank to return to the default value, Dismiss."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.TitleText]]
    name = "TitleText"
    description = "Sets the title of the notification in the TitleText variable. It is mandatory to set this variable."
    type = "String/Text"
    mandatory = true
    default_value = ""

    [[script.AttributionText]]
    name = "AttributionText"
    description = "Sets the attribution text in the AttributionText variable. It can be a company name or website, for authenticity. If not set, it defaults to the organization name."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.BodyText1]]
    name = "BodyText1"
    description = "BodyText1 stores the main text content of the notification body. It is a mandatory variable. Avoid using double quotes in the text."
    type = "String/Text"
    mandatory = true
    default_value = ""

    [[script.BodyText2]]
    name = "BodyText2"
    description = "BodyText2 stores the secondary text content of the notification body. Avoid using double quotes in the text."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.LogoImage]]
    name = "LogoImage"
    description = "LogoImage stores the URL or local path for the logo image in the notification. Leave it blank to generate the notification with the default logo."
    type = "String/Text"
    mandatory = false$
    default_value = ""

    [[script.HeroImage]]
    name = "HeroImage"
    description = "HeroImage stores the URL or local path for the primary image in the notification. Leave it blank to generate the notification with the default image."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.Deadline]]
    name = "Deadline"
    description = "Sets the deadline for the notification. Format: yyyy-MM-dd HH:mm:ss. Note that RunScriptButton and Deadline cannot be enabled at the same time. Additionally, enabling RunScriptButton will automatically disable Deadline."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.MaxUptimeDays]]
    name = "MaxUptimeDays"
    description = "Defines the maximum uptime (in days) for the PendingRebootUptime NotificationType parameter. Default is 30 days."
    type = "Integer"
    mandatory = false
    default_value = ""

    [[script.ADPasswordExpirationDays]]
    name = "ADPasswordExpirationDays"
    description = "Number of days before password expiration when reminders should start. It is available for the ADPasswordExpiration NotificationType parameter. Default is 7 days."
    type = "Integer"
    mandatory = false
    default_value = ""

    [[script.Repeat]]
    name = "Repeat"
    description = "Specifies how frequently the notification should repeat. Options: Once, Hourly, XXMinutes, XXHours, Daily, XXDays. Default is Once."
    type = "String/Text"
    mandatory = false
    default_value = ""

    [[script.NotificationAppName]]
    name = "NotificationAppName"
    description = "Specifies the name of the application that will display the notification."
    type = "String/Text"
    mandatory = false
    default_value = "Windows PowerShell"

    [[script.MaxOccurrences]]
    name = "MaxOccurrences"
    description = "Specifies the maximum number of notifications to send before the scheduled task is automatically removed. This works in conjunction with the Repeat parameter, except when Repeat is set to Once."
    type = "Integer"
    mandatory = false
    default_value = ""
#>

$NotificationType = "$env:NotificationType"
$RebootButton = "$env:RebootButton"
$RunScriptButtonText = "$env:RunScriptButtonText"
$ScriptPath = "$env:ScriptPath"
$ScriptContext = "$env:ScriptContext"
$LearnMoreUrl = "$env:LearnMoreUrl"
$HideDismissButton = "$env:HideDismissButton"
$DismissButtonText = "$env:DismissButtonText"
$TitleText = "$env:TitleText"
$AttributionText = "$env:AttributionText"
$BodyText1 = "$env:BodyText1"
$BodyText2 = "$env:BodyText2"
$LogoImage = "$env:LogoImage"
$HeroImage = "$env:HeroImage"
$Deadline = "$env:Deadline"
$MaxUptimeDays = "$env:MaxUptimeDays"
$ADPasswordExpirationDays = "$env:ADPasswordExpirationDays"
$Repeat = "$env:Repeat"
$NotificationAppName = "$env:NotificationAppName"
$MaxOccurrences = "$env:MaxOccurrences"

if ($NotificationType -notin ('Generic', 'PendingRebootUptime', 'PendingRebootCheck', 'ADPasswordExpiration')) {
    throw "NotificationType can either be 'Generic', 'PendingRebootUptime', 'PendingRebootCheck', 'ADPasswordExpiration'."
} else {
    $NotificationType = $NotificationType
}

if (($RebootButton -match '1|Yes|True|Y') -and ( $NotificationType -in ('Generic', 'PendingRebootUptime', 'PendingRebootCheck'))) {
    $RebootButton = $true
} else {
    $RebootButton = $false
}

if (($RunScriptButtonText).length -ge 1) {
    $RunScriptButton = $true
} else {
    $RunScriptButton = $false
}

if (($RunScriptButtonText).length -ge 1) {
    $RunScriptButtonText = $RunScriptButtonText
} else {
    $RunScriptButtonText = ''
}

if (($ScriptPath).Length -ge 3 -and $RunScriptButton) {
    $ScriptPath = $ScriptPath
} else {
    $ScriptPath = ''
}

if (!$ScriptPath -and $RunScriptButton) {
    return 'ScriptPath is not provided and RunScriptButton is enabled.'
}

if ($ScriptContext -match 'User|System' -and $RunScriptButton) {
    $ScriptContext = $ScriptContext
} else {
    $ScriptContext = ''
}

if ($LearnMoreUrl -match ('^[hf]t{1,2}ps{0,1}')) {
    $LearnMoreButton = $true
} else {
    $LearnMoreButton = $false
}

if ($LearnMoreUrl -match ('^[hf]t{1,2}ps{0,1}')) {
    $LearnMoreUrl = $LearnMoreUrl
} else {
    $LearnMoreUrl = ''
}

if ($HideDismissButton -match '1|Yes|True|Y') {
    $HideDismissButton = $true
} else {
    $HideDismissButton = $false
}

if ((($DismissButtonText).length -le 2) -and ($HideDismissButton -eq $false)) {
    $DismissButtonText = ''
} else {
    $DismissButtonText = $DismissButtonText
}

if ((($TitleText).length -le 2 )) {
    return 'TitleText is mandatory to Set the title of the notification'
} else {
    $TitleText = $TitleText
}

if ((($AttributionText).length -le 2)) {
    $AttributionText = $env:NINJA_ORGANIZATION_NAME
} else {
    $AttributionText = $AttributionText
}

if ((($BodyText1).length -le 2 )) {
    return 'BodyText1 is mandatory to Set the main text content of the notification body'
} else {
    $BodyText1 = $BodyText1
}

if ((($BodyText2).length -le 2)) {
    $BodyText2 = ''
} else {
    $BodyText2 = $BodyText2
}

if (($LogoImage).length -gt 2) {
    $LogoImage = $LogoImage
} else {
    $LogoImage = ''
}

if (($HeroImage).length -gt 2) {
    $HeroImage = $HeroImage
} else {
    $HeroImage = ''
}

if ($Deadline -match '\d{4}-\d{2}-\d{2}' -and $RunScriptButton -eq $false) {
    $Deadline = [datetime]$Deadline
} else {
    $Deadline = ''
}

if (($MaxUptimeDays -match '^[0-9]{1,}$') -and ($NotificationType -match 'PendingRebootUptime')) {
    $MaxUptimeDays = $MaxUptimeDays
} else {
    $MaxUptimeDays = ''
}

if (($ADPasswordExpirationDays -match '^[0-9]{1,}$') -and (($ADPasswordExpirationDays).length -gt 2) -and ($NotificationType -match 'ADPasswordExpiration')) {
    $ADPasswordExpirationDays = $ADPasswordExpirationDays
} else {
    $ADPasswordExpirationDays = ''
}

if (($Repeat -match '^(Once|Hourly|[0-9]{1,}Minutes|[0-9]{1,}Hours|Daily|[0-9]{1,}Days|Weekly|Monthly|AtLogon)$') -and (($Repeat).length -gt 2)) {
    $Repeat = $Repeat
} else {
    $Repeat = 'Once'
}

if ($NotificationAppName -match '[0-9A-z]{1,}' -and (($NotificationAppName).length -gt 2)) {
    $NotificationAppName = $NotificationAppName
} else {
    $NotificationAppName = ''
}

if ($MaxOccurrences -match '[0-9]{1,}' -and (($MaxOccurrences).length -ge 1)) {
    $MaxOccurrences = $MaxOccurrences
} else {
    $MaxOccurrences = ''
}

$parameters = @{
    TitleText = $TitleText
    BodyText1 = $BodyText1
    Repeat = $Repeat
}

switch ($NotificationType) {
    'Generic' {
        $parameters.Add('Generic', $true)
    }
    'PendingRebootUptime' {
        $parameters.Add('PendingRebootUptime', $true)
    }
    'PendingRebootCheck' {
        $parameters.Add('PendingRebootCheck', $true)
    }
    'ADPasswordExpiration' {
        $parameters.Add('ADPasswordExpiration', $true)
    }
    default {
        $parameters.Add('Generic', $true)
    }
}

if ($RebootButton -eq $true) { $parameters.Add('RebootButton', $RebootButton) }
if ($RunScriptButton -eq $true) { $parameters.Add('RunScriptButton', $RunScriptButton) }
if ($RunScriptButtonText -ne '') { $parameters.Add('RunScriptButtonText', $RunScriptButtonText) }
if ($ScriptPath -ne '') { $parameters.Add('ScriptPath', $ScriptPath) }
if ($ScriptContext -ne '') { $parameters.Add('ScriptContext', $ScriptContext) }
if ($LearnMoreButton -eq $true) { $parameters.Add('LearnMoreButton', $LearnMoreButton) }
if ($LearnMoreUrl -ne '') { $parameters.Add('LearnMoreUrl', $LearnMoreUrl) }
if ($HideDismissButton -ne '') { $parameters.Add('HideDismissButton', $HideDismissButton) }
if ($DismissButtonText -ne '') { $parameters.Add('DismissButtonText', $DismissButtonText) }
if ($AttributionText -ne '') { $parameters.Add('AttributionText', $AttributionText) }
if ($BodyText2 -ne '') { $parameters.Add('BodyText2', $BodyText2) }
if ($LogoImage -ne '') { $parameters.Add('LogoImage', $LogoImage) }
if ($HeroImage -ne '') { $parameters.Add('HeroImage', $HeroImage) }
if ($Deadline -ne '') { $parameters.Add('Deadline', $Deadline) }
if ($MaxUptimeDays -ne '') { $parameters.Add('MaxUptimeDays', $MaxUptimeDays) }
if ($ADPasswordExpirationDays -ne '') { $parameters.Add('ADPasswordExpirationDays', $ADPasswordExpirationDays) }
if ($NotificationAppName -ne '') { $parameters.Add('NotificationAppName', $NotificationAppName) }
if ($MaxOccurrences -ne '') { $parameters.Add('MaxOccurrences', $MaxOccurrences) }

#region Setup - Variables
$ProjectName = 'Invoke-ToastNotification'
[Net.ServicePointManager]::SecurityProtocol = [enum]::ToObject([Net.SecurityProtocolType], 3072)
$BaseURL = 'https://file.provaltech.com/repo'
$PS1URL = "$BaseURL/script/$ProjectName.ps1"
$WorkingDirectory = "C:\ProgramData\_automation\script\$ProjectName"
$PS1Path = "$WorkingDirectory\$ProjectName.ps1"
$LogPath = "$WorkingDirectory\$ProjectName-log.txt"
$ErrorLogPath = "$WorkingDirectory\$ProjectName-Error.txt"
#endregion

#region Setup - Folder Structure
New-Item -Path $WorkingDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

if (-not ( ( ( Get-Acl $WorkingDirectory ).Access | Where-Object { $_.IdentityReference -match 'EveryOne' } ).FileSystemRights -match 'FullControl' ) ) {
    $Acl = Get-Acl $WorkingDirectory
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'none', 'Allow')
    $Acl.AddAccessRule($AccessRule)
    Set-Acl $WorkingDirectory $Acl
}

$response = Invoke-WebRequest -Uri $PS1URL -UseBasicParsing

if (($response.StatusCode -ne 200) -and (!(Test-Path -Path $PS1Path))) {
    return "No pre-downloaded script exists and the script '$PS1URL' failed to download. Exiting."
} elseif ($response.StatusCode -eq 200) {
    Remove-Item -Path $PS1Path -ErrorAction SilentlyContinue
    [System.IO.File]::WriteAllLines($PS1Path, $response.Content)
}

if (!(Test-Path -Path $PS1Path)) {
    return 'An error occurred and the script was unable to be downloaded. Exiting.'
}
#endregionSetup

#region Execution
Write-Information "Executing $PS1Path with parameters: $($parameters | Out-String)" -InformationAction Continue
if ($parameters) {
    & $PS1Path @parameters
} else {
    & $PS1Path
}
#endregion

if (!(Test-Path $LogPath)) {
    return 'PowerShell Failure. A Security application seems to have restricted the execution of the PowerShell Script.'
}

$logContent = Get-Content -Path $LogPath
$logContent[ $($($logContent.IndexOf($($logContent -match "$($ProjectName)$")[-1])) + 1)..$($logContent.length - 1) ]

if (Test-Path $ErrorLogPath) {
    $ErrorContent = (Get-Content -Path $ErrorLogPath)
    return ($ErrorContent | Out-String)
}