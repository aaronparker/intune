<#
    Export Intune configuration to disk.
    Ensure the Intune PowerShell SDK module is imported and you have connected to the MSGraph API
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $Path = $pwd
)

#region Functions
Function Remove-InvalidFileNameChars {
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [String]$Name
    )
  
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    Write-Output ($Name -replace $re)
}

Function Export-IntuneConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter()] $Target,
        [Parameter()] $Path
    )
    ForEach ($config in $Target) {
        If ($config | Get-Member -Name '@odata.type') {
            $type = $config.'@odata.type' -replace '#microsoft.graph.', ''
        }
        ElseIf ($config | Get-Member -Name 'deviceCategoryODataType') {
            $type = $config.deviceCategoryODataType -replace 'microsoft.graph.', ''
        }

        # Fix filename, remove invalid chars
        $fileName = "$($type)_$($config.displayName -replace '\s','')" | Remove-InvalidFileNameChars
        $fileName = "$($fileName.TrimEnd("-")).json"

        # Export the configuration object to JSON
        Write-Verbose -Message "Export config: $fileName."
        $config | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
    }
}

Function Export-IntuneAssignment {
    [CmdletBinding()]
    Param (
        [Parameter()]
        $Assignment,

        [Parameter()]
        [string] $Path
    )
    ForEach ($item in $Assignment) {
        $assignment = switch -Wildcard ($item.'@odata.type') {
            '#microsoft.graph.*FeaturesConfiguration' {
                Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $item.id
            }
            '#microsoft.graph.*UpgradeConfiguration' {
                Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $item.id
            }
            '#microsoft.graph.*GeneralConfiguration' {
                Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $item.id
            }
            '#microsoft.graph.*DeviceConfiguration' {
                Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $item.id
            }
            '#microsoft.graph.*CustomConfiguration' {
                Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $item.id
            }
            '#microsoft.graph.*CompliancePolicy' {
                Get-IntuneDeviceCompliancePolicyAssignment -deviceCompliancePolicyId $item.id
            }
            '#microsoft.graph.*App' {
                Get-IntuneMobileAppAssignment -mobileAppId $item.id
            }
            <#'#microsoft.graph.androidManagedAppProtection' {
                Get-IntuneAppProtectionPolicyAndroidAssignment -androidManagedAppProtectionId $item.id -androidManagedAppProtectionODataType $item.'@odata.type'.Trim("#")
            }
            '#microsoft.graph.iosManagedAppProtection' {
                Get-IntuneAppProtectionPolicyIosAssignment -iosManagedAppProtectionId $item.id -iosManagedAppProtectionODataType $item.'@odata.type'.Trim("#")
            }#>    
            Default {
                If ($Null -eq $item.'@odata.type') { $type = $item.'deviceCategoryODataType' } Else { $type = $item.'@odata.type' }
                Write-Warning -Message "OData object passed to Export-IntuneAssignment was not an understood: $type"
            }
        }
        If ($Null -ne $assignment) {
            # Fix filename, remove invalid chars
            $fileName = "$($item.displayName -replace '\s','')" | Remove-InvalidFileNameChars
            $fileName = "Assignments-$($fileName.TrimEnd("-"))-$($item.'@odata.type'.Split(".") | Select-Object -Last 1).json"

            # Export the configuration object to JSON
            Write-Verbose -Message "Export assignment: $fileName."
            $assignment | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
        }
    }
}
#endregion


#region Required modules
$modules = @('AzureADPreview', 'Microsoft.Graph.Intune', 'WindowsAutoPilotIntune')
ForEach ($module in $modules) {
    If ($Null -eq (Get-Module -Name $module)) {
        Write-Error "Required module not installed: $module."
        $moduleErr = $True
    }
}
If ($moduleErr) {
    Throw "Failed to find required modules."
    Break
}
#endregion


#region Create folder
# Create folder below target path with date and time
$Path = Join-Path -Path (Resolve-Path $pwd) -ChildPath "$((Get-Date -Format "yyyyMMMdd-HHmmss"))"
If ((Test-Path -Path $Path)) {
    Write-Verbose "$Path exists."
}
Else {
    Write-Verbose "Export path: $Path"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}
#endregion


#region Export
# Export Intune details out to JSON files
$objects = @('Get-IntuneDeviceConfigurationPolicy', `
        'Get-IntuneDeviceCompliancePolicy', `
        'Get-IntuneDeviceEnrollmentConfiguration', `
        'Get-IntuneDeviceCategory', `
        'Get-IntuneWindowsInformationProtectionPolicy', `
        'Get-IntuneAppProtectionPolicy', `
        'Get-IntuneMobileApp', `
        'Get-IntuneRoleAssignment', `
        'Get-IntuneVppToken', `
        'Get-IntuneApplePushNotificationCertificate')
ForEach ($object in $objects) {
    $items = Invoke-Expression $object
    Export-IntuneConfiguration -Target $items -Path $Path
    Export-IntuneAssignment -Assignment $items -Path $Path
}
#endregion
