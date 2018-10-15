# Get device configuration profile types
Get-DeviceManagement_DeviceConfigurations | Select-Object '@odata.type', DisplayName

# Get Windows 10 device configuration profiles and show display names
$type = "#microsoft.graph.windows10*"
Get-DeviceManagement_DeviceConfigurations | Where-Object { $_.'@odata.type' -like $type } | Select-Object DisplayName

# Get settings for a specific device configuration profile
$deviceProfile = Get-DeviceManagement_DeviceConfigurations | Where-Object { $_.DisplayName -eq "Windows 10 Device restrictions" }
