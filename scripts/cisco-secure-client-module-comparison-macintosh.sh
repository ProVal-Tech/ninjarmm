#!/bin/bash

################################################################################
# SYNOPSIS
#   Compares the number of installed Cisco Secure Client modules with the 
#   number of selected modules in NinjaRMM custom fields.
#
# DESCRIPTION
#   This script is designed to be executed as a pre-check script within a 
#   NinjaRMM compound condition. It performs a comparison between the number 
#   of Cisco Secure Client modules currently installed on the system and the 
#   number of modules selected in the NinjaRMM custom field configuration.
#
#   The script performs the following operations:
#   - Retrieves the list of installed Cisco Secure Client modules from macOS
#   - Retrieves the list of selected modules from the NinjaRMM custom field
#   - Compares the count of installed modules with the count of selected modules
#   - Returns an exit code based on the comparison result
#
#   This script is typically used in a compound condition workflow where:
#   - Exit code 0: The number of installed modules matches the number of 
#                  selected modules (no action required)
#   - Exit code 1: The counts differ, triggering the installation script 
#                  ("Cisco Secure Client - Package Installation [Macintosh]")
#   - Exit code 2: No modules are selected in the custom field 
#                  (configuration error)
#
#   When the script exits with code 1, it indicates that the installation 
#   script should be executed to bring the system into the desired state by 
#   installing the missing modules.
#
# NOTES
#   name = "Cisco Secure Client - Module Comparison [Macintosh]"
#   description = "Compares the number of installed Cisco Secure Client modules with the number of modules selected in the 'cPVAL Cisco Secure Client Modules' custom field. Used as a pre-check in compound conditions to determine if installation is required."
#   categories = "ProVal"
#   language = "ShellScript"
#   operating_system = "Mac"
#   architecture = "64-bit"
#   run_as = "System"
#
# COMPONENT
#   This script requires NinjaRMM CLI (ninjarmm-cli) to retrieve custom field 
#   values. The script must be executed within a NinjaRMM automation context.
#
#   CUSTOM FIELDS CONFIGURATION:
#   The script reads configuration from the following NinjaRMM custom field:
#
#   cPVAL Cisco Secure Client Modules (cpvalCiscoSecureClientModules)
#       Type: Multi-select
#       Mandatory: Yes
#       Description: This field specifies which modules should be installed. 
#                    The script compares the count of modules selected in this 
#                    field with the count of modules currently installed on the 
#                    system. If "All" is selected, the script compares against 
#                    all available macOS modules.
#
# EXAMPLE
#   This script is typically executed as part of a NinjaRMM compound condition 
#   workflow:
#
#   Compound Condition Setup:
#   1. Configure the "cPVAL Cisco Secure Client Modules" custom field with 
#      desired modules
#   2. Set this script as the pre-check script in the compound condition
#   3. Configure "Cisco Secure Client - Package Installation [Macintosh]" to run 
#      when this script exits with code 1
#   4. The compound condition will automatically trigger installation when 
#      module counts differ
#
#   Example workflow:
#   - Pre-check: "Cisco Secure Client - Module Comparison [Macintosh]" (this script)
#   - Condition: Exit code equals 1
#   - Action: Execute "Cisco Secure Client - Package Installation [Macintosh]"
#
# EXIT CODES
#   0 - Success: The number of installed modules matches the number of selected 
#                modules. No installation required.
#   1 - Mismatch: The number of installed modules differs from the number of 
#                 selected modules. Installation script should be triggered.
#   2 - Configuration Error: No modules have been selected in the custom field. 
#                            Manual configuration required.
#
# INPUTS
#   None. This script does not accept command-line arguments. All 
#   configuration is retrieved from NinjaRMM custom fields.
#
# OUTPUTS
#   The script writes informational messages to the console, including:
#   - Count and list of installed modules
#   - Count and list of selected modules
#   - Comparison result and action recommendation
#
# LINK
#   https://content.provaltech.com/docs/4c8a8b02-7357-4cac-8f30-c5b0814a655b
#
################################################################################

# Variables
modulesCustomField='cpvalCiscoSecureClientModules'
applicationPath='/Applications'

# Fetch ninjarmm-cli path
if [ -f '/Applications/NinjaRMMAgent/programdata/ninjarmm-cli' ]; then
    ninjarmm_cli='/Applications/NinjaRMMAgent/programdata/ninjarmm-cli'
elif [ -f '/opt/NinjaRMMAgent/programdata/ninjarmm-cli' ]; then
    ninjarmm_cli='/opt/NinjaRMMAgent/programdata/ninjarmm-cli'
else
    echo 'ERROR: ninjarmm-cli not found on this system'
    exit 2
fi

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
fi

# Get selected modules
selectedModulesGuid="$($ninjarmm_cli get "$modulesCustomField")"
if [ -z "$selectedModulesGuid" ]; then
    echo "No modules have been selected for installation. Please configure the 'cPVAL Cisco Secure Client Modules' custom field with the desired modules and re-run the script."
    exit 2
fi

availableModules="$($ninjarmm_cli options "$modulesCustomField")"
IFS=',' read -ra selectedModulesGuidArray <<< "${selectedModulesGuid// /}"
selectedModules=()
for selectedModuleGuid in "${selectedModulesGuidArray[@]}"; do
    moduleName=$(echo "$availableModules" | grep "$selectedModuleGuid" | cut -d'=' -f2)
    if [ -n "$moduleName" ]; then
        selectedModules+=("$moduleName")
    fi
done

# If "All" is selected, expand to all macOS modules
allSelected=false
for module in "${selectedModules[@]}"; do
    if [[ "$module" == 'All' ]]; then
        allSelected=true
        break
    fi
done

if [ "$allSelected" = true ]; then
    selectedModules=(
        'Core-VPN'
        'Umbrella'
        'Diagnostic And Reporting Tool'
        'Network Visibility Module'
        'ISE Posture'
        'Zero Trust Access'
        'ThousandEyes Endpoint'
        'Duo (Mac Only)'
        'Fireamp (Mac Only)'
        'Secure Firewall Posture (Mac Only)'
    )
fi

selectedCount=${#selectedModules[@]}
echo "Number of selected modules: $selectedCount"
echo "Selected modules:"
printf '%s\n' "${selectedModules[@]}"

# Compare installed and selected modules
if [ "$installedCount" -ge "$selectedCount" ]; then
    echo "The number of installed modules matches the number of selected modules. No installation action is required."
    exit 0
else
    echo "The number of installed modules does not match the number of selected modules. The installation script will be triggered to synchronize the module configuration."
    exit 1
fi