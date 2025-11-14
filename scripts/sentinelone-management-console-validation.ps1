<#
.SYNOPSIS
    Compares the SentinelOne Management Server URL configured on the endpoint with the client-level URL stored in NinjaOne, and records the result.

.DESCRIPTION
    This script is designed for environments using SentinelOne endpoint protection and NinjaOne RMM. It performs the following actions:
    - Retrieves the SentinelOne Management Server URL from the endpoint using SentinelCtl.exe.
    - Retrieves the client-level SentinelOne Management Server URL from a NinjaOne custom field (base64-encoded JSON).
    - Compares the two URLs.
    - Records the endpoint's Management Server URL and the result of the comparison in NinjaOne custom fields.
    - Sets an exit code indicating whether the URLs match (0 for match, 1 for mismatch).

.PARAMETER S1 Key Custom Field Name
    s1KeyCustomFieldName
        (Optional) Overrides the default custom field name for the SentinelOne key in NinjaOne.

.REQUIREMENTS
    - NinjaOne PowerShell module with Ninja-Property-Get and Ninja-Property-Set cmdlets.
    - SentinelOne agent installed on the endpoint.
    - Access to SentinelCtl.exe via the registry path.

.NOTES
    - The script should be run with appropriate permissions to access the registry and execute SentinelCtl.exe.
    - Custom field names can be customized by editing the script or setting the runtime variable.

.EXAMPLE
    S1 Key Custom Field Name = 'SentinelOne Key'

    Runs the script and compares the SentinelOne Management Server URL on the endpoint with the url fetched from the client-level key stored in 'SentinelOne Key' custom field.

.OUTPUTS
    - Writes informational messages to the output.
    - Sets NinjaOne custom fields:
        cPVAL SentinelOne Mgmt Server Url: Endpoint's Management Server URL.
        cPVAL SentinelOne Mgmt Server Discrepancy: 0 if URLs match, 1 if they do not.

.EXITCODES
    0 - URLs match or error encountered.
    1 - URLs do not match.

.NOTES
    [script]
    name = "SentinelOne Management Console Validation"
    description = "The script validates whether the SentinelOne Management Server detected on the computer is different from what is set for the Client in NinjaRMM."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"

    [[script.variables]]
    name = "S1 Key Custom Field Name"
    description = "Name of the client-level custom field used to store the SentinelOne installation key. Default is 'cPVAL SentinelOne Key'"
    type = "String/Text"
    mandatory = false
    default_value = "cPVAL SentinelOne Key"
#>
begin {
    #region Variables
    $defaultCFName = 'cpvalSentineloneKey'
    $compLevelCFName = 'cpvalSentineloneMgmtServerUrl'
    $compLevelMgmtDescCFName = 'cpvalSentineloneMgmtServerDiscrepancy'
    $sentinelCFName = $env:s1KeyCustomFieldName
    $sentinelCFName = if ([string]::IsNullOrEmpty($sentinelCFName)) {
        $defaultCFName
    } else {
        $sentinelCFName
    }
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SentinelAgent'
    $exitCode = 0
    #endRegion
} process {
    #region Control Path
    if (Test-Path -Path $regPath) {
        $ctlPath = "$((Get-ItemProperty -Path $regPath).ImagePath -Replace 'Sentinel((Agent)|(ServiceHost))\.exe', 'SentinelCtl.exe' -Replace '"','')"
        if ( !(Test-Path -Path $ctlPath) ) {
            Write-Information 'SentinelCtl.exe not found.' -InformationAction Continue
            $exitCode = 0
            return
        }
    } else {
        Write-Information 'Sentinel Agent not found.' -InformationAction Continue
        $exitCode = 0
        return
    }
    #endRegion

    #region Get SentinelOne Configuration from NinjaOne
    $clientLevelKey = Ninja-Property-Get -Name $defaultCFName
    if ([string]::IsNullOrEmpty($clientLevelKey)) {
        Write-Information ('Client Level EDF ''{0}'' is not set.' -f $defaultCFName) -InformationAction Continue
        $exitCode = 0
        return
    }
    $json = [System.Text.Encoding]::UTF8.GetString($([System.Convert]::FromBase64String($clientLevelKey)))
    $obj = $json | ConvertFrom-Json
    $clientLevelUrl = $obj.url -replace '"', ''
    #endRegion

    #region Get SentinelOne Site Key from EndPoint
    $mgmtServer = cmd.exe /c "$ctlPath" config server.mgmtServer
    if ([string]::IsNullOrEmpty($mgmtServer)) {
        Write-Information 'Failed to get Management Server from SentinelCtl.exe' -InformationAction Continue
        $exitCode = 0
        return
    }
    $mgmtServer = $mgmtServer -replace '"', ''
    Ninja-Property-Set -Name $compLevelCFName -Value $mgmtServer
    #endRegion

    #region Compare SentinelOne Mgmt Url
    if ($clientLevelUrl -eq $mgmtServer) {
        Write-Information 'Client Level URL and Management Server match.' -InformationAction Continue
        $exitCode = 0
        return
    } else {
        Write-Information @"
Client Level and Computer Level Management Server Url do not match.
Client Level Management Server Url: $clientLevelUrl
Computer Level Management Server Url: $mgmtServer
"@ -InformationAction Continue
        $exitCode = 1
        return
    }
    #endRegion
} end {
    Ninja-Property-Set -Name $compLevelMgmtDescCFName -Value $exitCode
    exit $exitCode
}