#!/bin/bash

################################################################################
# SYNOPSIS
#   Uninstalls all Cisco Secure Client modules from macOS systems using the 
#   built-in uninstaller script.
#
# DESCRIPTION
#   This script is designed to be executed from NinjaRMM automation and 
#   facilitates the complete removal of Cisco Secure Client modules from macOS 
#   systems. It performs a comprehensive uninstallation by locating installed 
#   modules and executing the official Cisco Secure Client uninstaller script.
#
#   The script performs the following operations:
#   - Searches for installed Cisco Secure Client modules in /Applications
#   - Displays the count and list of installed modules
#   - Executes the official uninstaller script located at 
#     /opt/cisco/secureclient/bin/vpn_uninstall.sh
#   - Verifies successful removal by checking for remaining modules
#   - Returns appropriate exit codes based on the uninstallation result
#
#   This script provides a clean and reliable method to remove all Cisco Secure 
#   Client components from macOS endpoints through RMM automation, ensuring 
#   complete removal of the application and its associated modules.
#
# NOTES
#   name = "Cisco Secure Client - Package Uninstallation [Macintosh]"
#   description = "Uninstalls all Cisco Secure Client modules from macOS systems using the built-in uninstaller script. Verifies successful removal and reports any remaining components."
#   categories = "ProVal"
#   language = "ShellScript"
#   operating_system = "Mac"
#   architecture = "64-bit"
#   run_as = "System"
#
# COMPONENT
#   This script uses the official Cisco Secure Client uninstaller script that 
#   is installed alongside the application. The uninstaller script is located at:
#   /opt/cisco/secureclient/bin/vpn_uninstall.sh
#
#   The script searches for installed modules by looking for applications 
#   matching the pattern "Cisco Secure Client" in the /Applications directory.
#   All matching applications are removed during the uninstallation process.
#
#   PREREQUISITES:
#   - Cisco Secure Client must be installed on the system
#   - The uninstaller script must be present at the expected location
#   - Sufficient permissions to execute the uninstaller script
#
# EXAMPLE
#   This script is typically executed as a NinjaRMM automation to remove 
#   Cisco Secure Client from macOS endpoints.
#
#   Example workflow:
#   1. Execute the automation on the target macOS system
#   2. The script will automatically detect installed modules
#   3. The uninstaller will remove all Cisco Secure Client components
#   4. Verification confirms successful removal
#
#   Example output:
#   - "Number of installed modules: 3"
#   - "Installed modules: [list of modules]"
#   - "Running uninstall command"
#   - "Successfully uninstalled cisco secure client."
#
# EXIT CODES
#   0 - Success: All Cisco Secure Client modules have been successfully 
#                uninstalled. No remaining components detected.
#   1 - Failure: The uninstallation process failed or encountered an error. 
#                This may occur if:
#                - The /Applications directory does not exist
#                - The uninstaller script is not found at the expected location
#                - The uninstaller script failed to execute
#                - Some modules remain after uninstallation
#
# INPUTS
#   None. This script does not accept command-line arguments. It automatically 
#   detects and removes all Cisco Secure Client modules from the system.
#
# OUTPUTS
#   The script writes informational messages to the console, including:
#   - Count and list of installed modules before uninstallation
#   - Status of the uninstallation process
#   - Verification results showing any remaining modules (if uninstallation 
#     failed)
#   - Success confirmation when all modules are removed
#
# LINK
#   https://content.provaltech.com/docs/9cb4a893-f41a-486f-bc0d-f6338b510651
#
################################################################################

# Variables
applicationPath='/Applications'
uninstallerPath='/opt/cisco/secureclient/bin/vpn_uninstall.sh'

# Get number of installed modules
if [ -d "$applicationPath" ]; then
    echo "Searching for applications in: $applicationPath"
    echo "---"
    
    # Count matching applications
    installedCount=$(find "$applicationPath" -maxdepth 1 -name "*.app" | 
        xargs -n1 basename | 
        sed 's/.app$//' | 
        grep -i -E '^cisco secure client' | 
        wc -l | 
        tr -d ' ')
    
else
    installedCount=0
    echo "Directory $applicationPath does not exist"
    exit 1
fi

echo "Number of installed modules: $installedCount"

# Display the list of matched applications
if [ "$installedCount" -gt 0 ]; then
    echo "Installed modules:"
    find "$applicationPath" -maxdepth 1 -name "*.app" | 
        xargs -n1 basename | 
        sed 's/.app$//' | 
        grep -i -E '^cisco secure client'
else
    echo "No matching applications found"
    exit 0
fi

# Running uninstall command
if [ -d $uninstallerPath ]; then
    echo 'Running uninstall command'
    chmod +x $uninstallerPath
    $uninstallerPath
else 
    echo "Uninstaller $uninstallerPath does not exist."
    exit 1
fi

# Verifying uninstall
installedCount=$(find "$applicationPath" -maxdepth 1 -name "*.app" | 
    xargs -n1 basename | 
    sed 's/.app$//' | 
    grep -i -E '^cisco secure client' | 
    wc -l | 
    tr -d ' ')

if [ "$installedCount" -gt 0 ]; then
    echo "Failed to remove:"
    find "$applicationPath" -maxdepth 1 -name "*.app" | 
        xargs -n1 basename | 
        sed 's/.app$//' | 
        grep -i -E '^cisco secure client'
    exit 1
else
    echo "Successfully uninstalled cisco secure client."
    exit 0
fi
