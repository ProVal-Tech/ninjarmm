<#
.SYNOPSIS
    This script will remove the 'C:\Windows.old' directory if it is found on the endpoint.

.NOTES
    [script]
    name = "Remove Windows.old - Windows"
    description = "This script will remove the 'C:\Windows.old' directory if it is found on the endpoint."
    categories = ["ProVal"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "All"
    run_as = "System"
#>

if (Test-Path 'C:\Windows.old') { 
  try {
    Write-Host "Attempting to remove Windows.old directory"
    Remove-Item C:\Windows.old -Recurse -Force
  }
  catch {
    Write-Host "An error occurred: Failed to remove Windows.old directory. Reason: $($_.Exception.Message)" -Level Error
    return
  }
  if (!(Test-Path 'C:\Windows.old')) {
    Write-Host "Windows.old directory successfully removed."
  }
} 
else {
  Write-Host "Windows.old directory does not exist"
}