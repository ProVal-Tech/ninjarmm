#!/bin/bash

################################################################################
# SYNOPSIS
#   Installs Cisco Secure Client modules on macOS systems using the 
#   Install-Cisco_Secure_Client agnostic shell script.
#
# DESCRIPTION
#   This script is designed to be executed from NinjaRMM automation and 
#   facilitates the installation of Cisco Secure Client modules by retrieving 
#   configuration values from NinjaRMM custom fields and passing them as 
#   parameters to the agnostic Install-Cisco_Secure_Client shell script.
#
#   The script performs the following operations:
#   - Retrieves module selection and configuration values from NinjaRMM custom fields
#   - Validates required custom field values based on selected modules
#   - Downloads the Install-Cisco_Secure_Client agnostic script from ProVal's content repository
#   - Constructs parameters based on custom field values
#   - Executes the agnostic script with the appropriate parameters
#   - Verifies script execution and displays output
#
#   This script acts as a wrapper that bridges NinjaRMM custom field 
#   configuration with the underlying agnostic installation script, making it 
#   easier to deploy Cisco Secure Client modules across multiple endpoints 
#   through RMM automation.
#
# NOTES
#   name = "Cisco Secure Client - Package Installation [Macintosh]"
#   description = "Attempts to install the modules selected in "cPVAL Cisco Secure Client Modules" using the installer specified in "cPVAL Cisco Secure Client Mac Source," provided as either a download URL or a local file path. Applicable for Mac systems."
#   categories = "ProVal"
#   language = "Bash"
#   operating_system = "Mac"
#   architecture = "64-bit"
#   run_as = "System"
#
# COMPONENT
#   This script requires NinjaRMM CLI (ninjarmm-cli) to retrieve custom field 
#   values. The script must be executed within a NinjaRMM automation context.
#
#   CUSTOM FIELDS CONFIGURATION:
#   The script reads configuration from the following NinjaRMM custom fields:
#
#   cPVAL Cisco Secure Client Modules (cpvalCiscoSecureClientModules)
#       Type: Multi-select
#       Mandatory: Yes
#       Description: Use this field to specify which modules should be 
#                    installed. If you select "All," all available modules will 
#                    be installed regardless of other selections. Note: If the 
#                    Umbrella module is selected, you must configure UserID, 
#                    Fingerprint, and OrgID. Choosing "All" will override 
#                    individual selections and install every module.
#       Available Options:
#           - All
#           - Core-VPN
#           - Umbrella
#           - Diagnostic And Reporting Tool
#           - Network Visibility Module
#           - ISE Posture
#           - ThousandEyes Endpoint
#           - Zero Trust Access
#           - Start Before Login (Windows Only)
#           - Network Access Manager (Windows Only)
#           - VPN Posture (Windows Only)
#           - Duo (Mac Only)
#           - Fireamp (Mac Only)
#           - Secure Firewall Posture (Mac Only)
#
#   cPVAL Cisco Secure Client Mac Source (cpvalCiscoSecureClientMacSource)
#       Type: Text/String
#       Mandatory: Yes
#       Description: Provide the download URL or local file path for the .dmg 
#                    file used to install Cisco Secure Client modules on macOS 
#                    machines. Accepts HTTP/HTTPS/FTP URLs or absolute file 
#                    paths (e.g., /tmp/Cisco_Secure_Client.dmg).
#
#   cPVAL Cisco Secure Client Umbrella UserID (cpvalCiscoSecureClientUmbrellaUserid)
#       Type: Text/String
#       Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
#       Description: Provide the Umbrella UserID associated with your 
#                    organization. This field is required if you choose "All" 
#                    or select the Umbrella module for installation.
#
#   cPVAL Cisco Secure Client Umbrella Fingerprint (cpvalCiscoSecureClientUmbrellaFingerprint)
#       Type: Text/String
#       Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
#       Description: Provide the Umbrella Fingerprint associated with your 
#                    organization. This field is required if you choose "All" 
#                    or select the Umbrella module for installation.
#
#   cPVAL Cisco Secure Client Umbrella OrgID (cpvalCiscoSecureClientUmbrellaOrgid)
#       Type: Text/String
#       Mandatory: Conditional (Required when "All" or "Umbrella" module is selected)
#       Description: Provide the Umbrella OrgID associated with your 
#                    organization. This field is required if you choose "All" 
#                    or select the Umbrella module for installation.
#
# EXAMPLE
#   This script is typically executed as a NinjaRMM automation. Ensure all 
#   required custom fields are configured before execution.
#
#   Example workflow:
#   1. Configure "cPVAL Cisco Secure Client Modules" custom field with desired 
#      modules (e.g., "Core-VPN", "Umbrella")
#   2. Configure "cPVAL Cisco Secure Client Mac Source" with the installer 
#      .dmg file URL or path
#   3. If Umbrella is selected, configure UserID, Fingerprint, and OrgID 
#      custom fields
#   4. Execute the automation
#
# INPUTS
#   None. This script does not accept command-line arguments. All 
#   configuration is retrieved from NinjaRMM custom fields.
#
# OUTPUTS
#   The script writes output to the console. The underlying installation 
#   script creates temporary files in /tmp/Cisco_Secure_Client/ during 
#   execution, which are cleaned up upon completion.
#
# LINK
#   https://content.provaltech.com/docs/33918565-04a9-436e-84ff-f29cbdd27949
#
################################################################################

# Script Variables
projectName='Install-Cisco_Secure_Client'
workingDirectory='/tmp'
scriptFileName="${projectName}.sh"
scriptPath="${workingDirectory}/${scriptFileName}"
baseUrl='https://contentrepo.net/repo'
scriptUrl="${baseUrl}/script/${projectName}.sh"

# Ninja RMM variables
modulesCustomField='cpvalCiscoSecureClientModules'
sourceCustomField='cpvalCiscoSecureClientMacSource'
userIdCustomField='cpvalCiscoSecureClientUmbrellaUserid'
fingerprintCustomField='cpvalCiscoSecureClientUmbrellaFingerprint'
orgIdCustomField='cpvalCiscoSecureClientUmbrellaOrgid'

# Fetch ninjarmm-cli path
if [ -f '/Applications/NinjaRMMAgent/programdata/ninjarmm-cli' ]; then
    ninjarmm_cli='/Applications/NinjaRMMAgent/programdata/ninjarmm-cli'
elif [ -f '/opt/NinjaRMMAgent/programdata/ninjarmm-cli' ]; then
    ninjarmm_cli='/opt/NinjaRMMAgent/programdata/ninjarmm-cli'
else
    echo 'ERROR: ninjarmm-cli not found on this system'
    exit 1
fi

# Fetch custom field values
selectedModulesGuid="$($ninjarmm_cli get "$modulesCustomField")"
if [ -z "$selectedModulesGuid" ]; then
    echo 'ERROR: No modules have been selected for installation. Please configure the '\''cPVAL Cisco Secure Client Modules'\'' custom field with the desired modules and re-run the script.'
    exit 1
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

source="$($ninjarmm_cli get "$sourceCustomField")"
if [ -z "$source" ]; then
    echo 'ERROR: The installation source has not been configured. Please provide a valid URL or local file path to the Cisco Secure Client .dmg installer in the '\''cPVAL Cisco Secure Client Mac Source'\'' custom field and re-run the script.'
    exit 1
fi

if ! [[ "$source" =~ ^(https?|ftp|/): ]]; then
    echo 'ERROR: The installation source format is invalid. Please provide a valid URL (http://, https://, or ftp://) or absolute file path (starting with /) to the Cisco Secure Client .dmg installer in the '\''cPVAL Cisco Secure Client Mac Source'\'' custom field and re-run the script.'
    exit 1
fi

userId="$($ninjarmm_cli get "$userIdCustomField")"
fingerprint="$($ninjarmm_cli get "$fingerprintCustomField")"
orgId="$($ninjarmm_cli get "$orgIdCustomField")"

umbrellaSelected=false
for module in "${selectedModules[@]}"; do
    if [[ "$module" == 'Umbrella' ]] || [[ "$module" == 'All' ]]; then
        umbrellaSelected=true
        break
    fi
done

if [ "$umbrellaSelected" = true ] && [ -z "$userId" ]; then
    echo 'ERROR: The Umbrella UserID is required but has not been configured. Please enter the UserID value in the '\''cPVAL Cisco Secure Client Umbrella UserID'\'' custom field and re-run the script. This field is mandatory when the '\''All'\'' or '\''Umbrella'\'' module is selected.'
    exit 1
fi

if [ "$umbrellaSelected" = true ] && [ -z "$fingerprint" ]; then
    echo 'ERROR: The Umbrella Fingerprint is required but has not been configured. Please enter the Fingerprint value in the '\''cPVAL Cisco Secure Client Umbrella Fingerprint'\'' custom field and re-run the script. This field is mandatory when the '\''All'\'' or '\''Umbrella'\'' module is selected.'
    exit 1
fi

if [ "$umbrellaSelected" = true ] && [ -z "$orgId" ]; then
    echo 'ERROR: The Umbrella OrgID is required but has not been configured. Please enter the OrgID value in the '\''cPVAL Cisco Secure Client Umbrella OrgID'\'' custom field and re-run the script. This field is mandatory when the '\''All'\'' or '\''Umbrella'\'' module is selected.'
    exit 1
fi

# Set Parameters
downloadurl_param="$source"
anyconnect_vpn_param=0
fireamp_param=0
dart_param=0
secure_firewall_posture_param=0
ise_posture_param=0
nvm_param=0
umbrella_param=0
thousandeyes_param=0
duo_param=0
zta_param=0

allSelected=false
for module in "${selectedModules[@]}"; do
    if [[ "$module" == 'All' ]]; then
        allSelected=true
        break
    fi
done

if [ "$allSelected" = true ]; then
    anyconnect_vpn_param=1
    fireamp_param=1
    dart_param=1
    secure_firewall_posture_param=1
    ise_posture_param=1
    nvm_param=1
    umbrella_param=1
    thousandeyes_param=1
    duo_param=1
    zta_param=1
else
    for module in "${selectedModules[@]}"; do
        case "$module" in
            'Core-VPN')
                anyconnect_vpn_param=1
                ;;
            'Fireamp (Mac Only)')
                fireamp_param=1
                ;;
            'Diagnostic And Reporting Tool')
                dart_param=1
                ;;
            'Secure Firewall Posture (Mac Only)')
                secure_firewall_posture_param=1
                ;;
            'ISE Posture')
                ise_posture_param=1
                ;;
            'Network Visibility Module')
                nvm_param=1
                ;;
            'Umbrella')
                umbrella_param=1
                ;;
            'ThousandEyes Endpoint')
                thousandeyes_param=1
                ;;
            'Duo (Mac Only)')
                duo_param=1
                ;;
            'Zero Trust Access')
                zta_param=1
                ;;
        esac
    done
fi

if [ "$umbrella_param" -eq 1 ]; then
    orgid_param="$orgId"
    fingerprint_param="$fingerprint"
    userid_param="$userId"
else
    orgid_param=''
    fingerprint_param=''
    userid_param=''
fi

# Download Script
echo 'Downloading installation script...'
if [ -f "$scriptPath" ]; then
    echo 'Removing existing script file...'
    rm -f "$scriptPath"
fi

curl -L -o "$scriptPath" "$scriptUrl"

if [ ! -f "$scriptPath" ]; then
    echo "ERROR: Failed to download the installation script from $scriptUrl"
    exit 1
fi

echo 'Successfully downloaded the installation script.'

# Convert line endings from Windows (CRLF) to Unix (LF)
echo 'Converting line endings...'
if command -v dos2unix &> /dev/null; then
    dos2unix "$scriptPath"
elif command -v sed &> /dev/null; then
    sed -i '' 's/\r$//' "$scriptPath"
else
    # Fallback using tr
    tr -d '\r' < "$scriptPath" > "${scriptPath}.tmp" && mv "${scriptPath}.tmp" "$scriptPath"
fi

# Make script executable
chmod +x "$scriptPath"

# Echo the command that will be executed
echo ''
echo 'Executing command:'
echo "$scriptPath \"$downloadurl_param\" $anyconnect_vpn_param $fireamp_param $dart_param $secure_firewall_posture_param $ise_posture_param $nvm_param $umbrella_param $thousandeyes_param $duo_param $zta_param \"$orgid_param\" \"$fingerprint_param\" \"$userid_param\""
echo ''

# Execute the installation script
$scriptPath "$downloadurl_param" $anyconnect_vpn_param $fireamp_param $dart_param $secure_firewall_posture_param $ise_posture_param $nvm_param $umbrella_param $thousandeyes_param $duo_param $zta_param "$orgid_param" "$fingerprint_param" "$userid_param"

# Capture exit code
exitCode=$?

# Exit with the same code as the installation script
exit $exitCode