#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Intune
<#
    .SYNOPSIS
        Export a Microsoft Intune tenant configuration to disk.

    .NOTES
        Ensure the Intune PowerShell SDK module is imported and you have connected to the MSGraph API.

    .PARAMETER Path
        A path to where the Intune configuration will be exported. Defaults to the current directory.
        A sub-folder with the current date/time will be created in $Path.
#>
[CmdletBinding()]
Param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias("PSPath")]
    [string] $Path = $pwd
)

#region Functions
Function Remove-InvalidFileNameChars {
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [String] $Name
    )
  
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    Write-Output ($Name -replace $re)
}

Function Export-IntuneConfiguration {
    [CmdletBinding()]
    Param (
        [Parameter()]
        $Target,

        [Parameter()]
        [string] $Path,

        [Parameter()]
        [string] $Seperator = "_"
    )

    # Create $Path if it does not exist
    If (!(Test-Path -Path $Path)) {
        Write-Verbose "Export path: $Path"
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    ForEach ($item in $Target) {
        If ($item | Get-Member -Name '@odata.type') {
            $Type = $item.'@odata.type'.Split(".") | Select-Object -Last 1
        }
        ElseIf ($item | Get-Member -Name 'deviceCategoryODataType') {
            $Type = $item.deviceCategoryODataType.Split(".") | Select-Object -Last 1
        }
        Else {
            Write-Warning -Message "OData passed to $($MyInvocation.MyCommand) was not understood: [$($item.'@odata.type')] for [$($item.DisplayName)]"
            $Type = "unknownType"
        }

        # Fix filename, remove invalid chars
        $fileName = "$($item.displayName -replace '\s','')" | Remove-InvalidFileNameChars
        $fileName = "$Type$Seperator$($fileName.TrimEnd("-")).json"

        # Export the configuration object to JSON
        Write-Verbose -Message "Export config: $fileName."
        $item | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
    }
}

Function Export-IntuneAssignment {
    [CmdletBinding()]
    Param (
        [Parameter()]
        $Assignment,

        [Parameter()]
        [string] $Path,

        [Parameter()]
        [string] $Seperator = "_"
    )

    # Create $Path if it does not exist
    If (!(Test-Path -Path $Path)) {
        Write-Verbose "Export path: $Path"
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

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
            '#microsoft.graph.windowsMobileMSI' {
                Get-IntuneMobileAppAssignment -mobileAppId $item.id
            }
            '#microsoft.graph.deviceEnrollment*Configuration' {
                Get-IntuneDeviceEnrollmentConfigurationAssignment -deviceEnrollmentConfigurationId $item.id
            }
            '#microsoft.graph.deviceAndAppManagementRoleDefinition' {
                # Get-IntuneRoleAssignment -deviceAndAppManagementRoleAssignmentId $item.id
            }
            '#microsoft.graph.iosMobileAppConfiguration' {
                # Get-IntuneMobileAppConfigurationPolicyAssignment -managedDeviceMobileAppConfigurationAssignmentId $item.id -managedDeviceMobileAppConfigurationId
            }
            '#microsoft.graph.androidManagedAppProtection' {
                # Get-IntuneAppProtectionPolicyAndroidAssignment -androidManagedAppProtectionId $item.id -androidManagedAppProtectionODataType $item.'@odata.type'.Trim("#")
            }
            '#microsoft.graph.iosManagedAppProtection' {
                # Get-IntuneAppProtectionPolicyIosAssignment -iosManagedAppProtectionId $item.id -iosManagedAppProtectionODataType $item.'@odata.type'.Trim("#")
            }
            Default {
                Write-Warning -Message "OData passed to $($MyInvocation.MyCommand) was not understood: [$($item.'@odata.type')] for [$($item.DisplayName)]"
            }
        }
        If ($Null -ne $assignment) {
            If ($item | Get-Member -Name '@odata.type') {
                $Type = $item.'@odata.type'.Split(".") | Select-Object -Last 1
            }
            ElseIf ($item | Get-Member -Name 'deviceCategoryODataType') {
                $Type = $item.deviceCategoryODataType.Split(".") | Select-Object -Last 1
            }
            Else {
                $Type = "unknownType"
            }

            # Fix filename, remove invalid chars
            $fileName = "$($item.displayName -replace '\s','')" | Remove-InvalidFileNameChars
            $fileName = "Assignments$Seperator$Type$Seperator$($fileName.TrimEnd("-")).json"

            # Export the configuration object to JSON
            Write-Verbose -Message "Export assignment: $fileName."
            $assignment | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
        }
    }
}
#endregion


#region Test environment
Try {
    Get-IntuneDeviceManagement -ErrorAction SilentlyContinue | Out-Null
}
Catch {
    Throw "Failed to find MSGraph connection. Please sign in first with Connect-MSGraph."
    Break
}
#endregion


#region Create folder
# Create folder below target path with date and time
$Path = Join-Path -Path (Resolve-Path $Path) -ChildPath "$((Get-Date -Format "yyyyMMMdd-HHmmss"))"
If ((Test-Path -Path $Path)) {
    Write-Verbose "$Path exists."
}
Else {
    Write-Verbose "Export path: $Path"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}
#endregion


#region Export Intune objects to local configuration files
# Export configurations
$objects = @('Get-IntuneDeviceConfigurationPolicy', `
        'Get-IntuneDeviceCompliancePolicy', `
        'Get-IntuneDeviceEnrollmentConfiguration', `
        'Get-IntuneDeviceCategory', `
        'Get-IntuneWindowsInformationProtectionPolicy', `
        'Get-IntuneMobileAppConfigurationPolicy', `
        'Get-IntuneAppProtectionPolicy', `
        'Get-IntuneMobileApp', `
        'Get-IntuneRoleDefinition', `
        'Get-IntuneVppToken', `
        'Get-IntuneManagedEBook', `
        'Get-IntuneRoleDefinition')
ForEach ($object in $objects) {
    $items = Invoke-Expression $object
    Export-IntuneConfiguration -Target $items -Path $Path
}

# Export assignments
$objects = @('Get-IntuneDeviceConfigurationPolicy', `
        'Get-IntuneDeviceCompliancePolicy', `
        'Get-IntuneWindowsInformationProtectionPolicy', `
        'Get-IntuneMdmWindowsInformationProtectionPolicy', `
        'Get-IntuneAppProtectionPolicy', `
        # 'Get-IntuneAppProtectionPolicyAndroidApp', `
        'Get-IntuneMobileApp', `
        # 'Get-IntuneMobileAppConfigurationPolicy', `
        'Get-IntuneManagedEBook', `
        'Get-IntuneDeviceEnrollmentConfiguration', `
        # 'Get-IntuneAppConfigurationPolicyTargeted', `
        'Get-IntuneRoleDefinition')
ForEach ($object in $objects) {
    $items = Invoke-Expression $object
    Export-IntuneAssignment -Assignment $items -Path $Path
}
#endregion
