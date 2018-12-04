<#
    Export Intune configuration to disk
#>

# Import the Intune PowerShell module
Import-Module "C:\Temp\Intune\Microsoft.Graph.Intune.psd1"

# Connect to Intune Graph API
Connect-MSGraph

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

Function Export-Configs {
    [CmdletBinding()]
    Param (
        [Parameter()] $Configs,
        [Parameter()] $Path
    )
    ForEach ($config in $Configs) {
        $fileName = "$($config.displayName -replace '\s','')-$($config.'@odata.type' -replace '#microsoft.graph.', '').json" | Remove-InvalidFileNameChars
        $config | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
    }
}

# Output path
$Path = "C:\Temp\IntuneConfigs"

# Get device policies and write out to JSON files
Export-Configs -Configs (Get-IntuneDeviceConfigurationPolicy) -Path $Path
Export-Configs -Configs (Get-IntuneDeviceCompliancePolicy) -Path $Path
Export-Configs -Configs (Get-IntuneDeviceEnrollmentConfiguration) -Path $Path
Export-Configs -Configs (Get-IntuneDeviceCategory) -Path $Path
Export-Configs -Configs (Get-IntuneWindowsInformationProtectionPolicy) -Path $Path
