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

Function Export-Configuration {
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
#endregion

# Required modules
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

# Create fodler below target path with date and time
$Path = Join-Path -Path (Resolve-Path $pwd) -ChildPath "$((Get-Date -Format "yyyyMMMdd-HHmmss"))"
If ((Test-Path -Path $Path)) {
    Write-Verbose "$Path exists."
}
Else {
    Write-Verbose "Creating: $Path"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}

# Get device policies and write out to JSON files
Export-Configuration -Target (Get-IntuneDeviceConfigurationPolicy) -Path $Path
Export-Configuration -Target (Get-IntuneDeviceCompliancePolicy) -Path $Path
Export-Configuration -Target (Get-IntuneDeviceEnrollmentConfiguration) -Path $Path
Export-Configuration -Target (Get-IntuneDeviceCategory) -Path $Path
Export-Configuration -Target (Get-IntuneWindowsInformationProtectionPolicy) -Path $Path
Export-Configuration -Target (Get-IntuneAppProtectionPolicy) -Path $Path
Export-Configuration -Target (Get-IntuneMobileApp) -Path $Path
Export-Configuration -Target (Get-IntuneRoleAssignment) -Path $Path
Export-Configuration -Target (Get-IntuneVppToken) -Path $Path
Export-Configuration -Target (Get-IntuneApplePushNotificationCertificate) -Path $Path


$compliancePolicies = Get-IntuneDeviceCompliancePolicy
ForEach ($policy in $compliancePolicies) {
    $assignment = Get-IntuneDeviceCompliancePolicyAssignment -deviceCompliancePolicyId $policy.id
    
    $fileName = "$($policy.displayName -replace '\s','')" | Remove-InvalidFileNameChars
    $fileName = "Assignments-$($fileName.TrimEnd("-")).json"

    Write-Verbose -Message "Export config: $fileName."
    $assignment | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
}
