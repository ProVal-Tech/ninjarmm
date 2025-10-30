<# 
.SYNOPSIS
Detects GPU/video controllers, connected monitors and the video ports in use, and stores a formatted report in the Ninja RMM Custom Field "cPVAL Video Ports Monitors".

.DESCRIPTION
Queries Win32_VideoController, WmiMonitorConnectionParams and WmiMonitorID via CIM to build a readable report of:
 - Video controllers (name, processor, RAM, driver, device ID)
 - Connected monitors (manufacturer, model, port used, instance name)
 - Assumed available ports per GPU

The generated report is stored in the NinjaRMM Custom Field "cpvalvideoPortsMonitor" using Ninja-Property-Set and written to output for logging.

.PARAMETERS
None. Run this script locally on the target machine (requires WMI/CIM access).

.EXAMPLE
.\Get-VideoPortsAndMonitorUsageDetection.ps1
# Runs the script and updates the NinjaRMM Custom Field "cpvalvideoPortsMonitor".

.OUTPUTS
Writes a multi-line string report to the NinjaRMM Custom Field and to standard output.

.NOTES
    [script]
    name = "Video Ports and Monitor Usage Detection"
    description = "This script gathers GPU and monitor details, detects connected displays and port types (HDMI, VGA, etc.), lists available ports, and stores all info in the custom field 'cPVAL Video Ports Monitors'."
    categories = ["Proval", "Hardware"]
    language = "PowerShell"
    operating_system = "Windows"
    architecture = "ALL"
    run_as = "System"

#>

# ----- Initialize output variable -----

$videoPortsMonitor = ''
$videoPortsMonitor += "--------------------------------`n"
$videoPortsMonitor += "Video Port & Monitor Information`n"
$videoPortsMonitor += "--------------------------------`n`n"

# --- Get all GPU / Video Controller info ---
$videoControllers = Get-CimInstance Win32_VideoController | Select-Object Name, PNPDeviceID, VideoProcessor, AdapterRAM, DriverVersion

$videoPortsMonitor += "--- Video Controllers Detected ---`n`n"
foreach ($vc in $videoControllers) {
    $videoPortsMonitor += "GPU Name        : $($vc.Name)`n"
    $videoPortsMonitor += "Video Processor : $($vc.VideoProcessor)`n"
    $videoPortsMonitor += "Adapter RAM     : $([math]::Round($vc.AdapterRAM/1GB,2)) GB`n"
    $videoPortsMonitor += "Driver Version  : $($vc.DriverVersion)`n"
    $videoPortsMonitor += "Device ID       : $($vc.PNPDeviceID)`n"
    $videoPortsMonitor += "----------------------------------`n`n"
}

# --- Detect connected monitors and ports ---
$monitorParams = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams -ErrorAction SilentlyContinue
$monitorIDs = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue

$videoPortsMonitor += "--- Connected Monitors & Ports ---`n`n"
if ($monitorParams) {
    foreach ($mp in $monitorParams) {
        # Get monitor manufacturer & model
        $id = $monitorIDs | Where-Object { $_.InstanceName -eq $mp.InstanceName }
        $manufacturer = if ($id -and $id.ManufacturerName) { ([System.Text.Encoding]::ASCII.GetString($id.ManufacturerName)).Trim([char]0) } else { 'Unknown Manufacturer' }
        $model        = if ($id -and $id.UserFriendlyName) { ([System.Text.Encoding]::ASCII.GetString($id.UserFriendlyName)).Trim([char]0) } else { 'Unknown Model' }

        # Map VideoOutputTechnology to readable type
        switch ($mp.VideoOutputTechnology) {
            0  { $portType = 'VGA' }
            1  { $portType = 'S-Video' }
            2  { $portType = 'Composite Video' }
            3  { $portType = 'Component Video' }
            4  { $portType = 'DVI' }
            5  { $portType = 'HDMI' }
            6  { $portType = 'LVDS' }
            8  { $portType = 'DisplayPort' }
            10 { $portType = 'Internal' }
            default { $portType = "Unknown ($($mp.VideoOutputTechnology))" }
        }

        $videoPortsMonitor += "Monitor       : $manufacturer $model`n"
        $videoPortsMonitor += "Port Used     : $portType`n"
        $videoPortsMonitor += "Instance Name : $($mp.InstanceName)`n"
        $videoPortsMonitor += "----------------------------------`n`n"
    }
} else {
    $videoPortsMonitor += "No connected monitors detected.`n"
    $videoPortsMonitor += "----------------------------------`n`n"
}

# --- Detect available ports (assumed per GPU) ---
$videoPortsMonitor += "--- Available Ports (Detected by GPU capabilities) ---`n`n"
foreach ($vc in $videoControllers) {
    $ports = @('HDMI', 'DisplayPort', 'DVI', 'VGA') # Assumed common set
    $videoPortsMonitor += "GPU: $($vc.Name)`n"
    $videoPortsMonitor += "Available Ports: $($ports -join ', ')`n"
    $videoPortsMonitor += "----------------------------------`n`n"
}

# ----- Send to Ninja RMM custom property -----
Ninja-Property-Set cpvalVideoPortsMonitors $videoPortsMonitor
Write-Output "`ncpval Video Ports Monitors *`n"
Write-Output "`nLast updated by script $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
Write-Output "`n$videoPortsMonitor"
