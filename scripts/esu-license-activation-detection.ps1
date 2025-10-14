<#
.SYNOPSIS
    This script performs the checks for the ESU license activation detection and stores the info in the custom field "cPVAL ESU Status".

.NOTES
    [script]
    name = "ESU License Activation Detection"
    description = "This script performs the checks for the ESU license activation detection and stores the info in the custom field 'cPVAL ESU Status'""
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

$cfName = 'cpvalEsuStatus'
try {
    # Check if the OS is Windows 10
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Caption -notlike "*Windows 10*") {
        $value = "Not Windows 10"
    } else {
        # Try to get the ESU license status
        $esu = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.ID -like 'f520e45e-7413-4a34-a497-d2765967d094' }

        if ($null -eq $esu) {
            $value = "ESU license info not found"
        } elseif ($esu.LicenseStatus -eq 1) {
            $value = "ESU activated"
        } else {
            $value = "ESU not activated"
        }
    }
} catch {
    $value = "PowerShell failure"
}

# Output the result
Write-Output $value

Ninja-Property-Set -Name $cfName -Value $value