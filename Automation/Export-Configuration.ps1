<#
    Export Intune configuration to disk.
    Ensure the Intune PowerShell SDK is imported and you have connected to the MSGraph API
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $Path = $pwd
)

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

Function Export-Config {
    [CmdletBinding()]
    Param (
        [Parameter()] $Configuration,
        [Parameter()] $Path
    )
    ForEach ($config in $Configuration) {

        If ($config | Get-Member -Name '@odata.type') {
            $type = $config.'@odata.type' -replace '#microsoft.graph.', ''
        } ElseIf ($config | Get-Member -Name 'deviceCategoryODataType') {
            $type = $config.deviceCategoryODataType -replace 'microsoft.graph.', ''
        }

        $fileName = "$($type)_$($config.displayName -replace '\s','')" | Remove-InvalidFileNameChars
        $fileName = "$($fileName.TrimEnd("-")).json"

        Write-Verbose -Message "Export config: $($config.displayName) to $fileName."
        $config | ConvertTo-Json | Add-Content -Path (Join-Path $Path $fileName)
    }
}

# Get device policies and write out to JSON files
Export-Config -Configuration (Get-IntuneDeviceConfigurationPolicy) -Path $Path
Export-Config -Configuration (Get-IntuneDeviceCompliancePolicy) -Path $Path
Export-Config -Configuration (Get-IntuneDeviceEnrollmentConfiguration) -Path $Path
Export-Config -Configuration (Get-IntuneDeviceCategory) -Path $Path
Export-Config -Configuration (Get-IntuneWindowsInformationProtectionPolicy) -Path $Path
