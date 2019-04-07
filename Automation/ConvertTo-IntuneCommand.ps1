#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Intune
<#
    .SYNOPSIS
        Convert a source configuration object from an Intune tenant into a Microsoft.Graph.Intune command

    .NOTES

#>
[CmdletBinding()]
Param (
)

# Read Intune device configuration policies
$configs = Get-IntuneDeviceConfigurationPolicy

# Select the values we need to create a command line for New-IntuneDeviceConfigurationPolicy
$values = $configs[0] | Select-Object -Property * `
    -ExcludeProperty @("@odata.type", "id", "lastModifiedDateTime", "createdDateTime", "version", `
        "deviceConfigurationId", "deviceConfigurationODataType", "windows10EndpointProtectionConfigurationReferenceUrl")
$values.displayName = "Test-Win10-Corp-EndpointProtection"
$values | Add-Member -NotePropertyName "ODataType" -NotePropertyValue $configs[0]."@odata.type"

# Convert the PSCustomObject to a hashtable 
$params = @{}
ForEach($property in $values.PSObject.Properties.Name) {
    If ($Null -ne $values.$property) {
        $params[$property] = $values.$property
    }
}

# Write command line to pipeline
# ($params.Keys | ForEach { "$_ $($params[$_])" }) -join " -"

# Create the configuration with New-IntuneDeviceConfigurationPolicy
New-IntuneDeviceConfigurationPolicy @params
