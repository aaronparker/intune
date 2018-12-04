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

# Get configurations
$configs = Get-IntuneDeviceConfigurationPolicy
ForEach ($config in $configs) {
    $fileName = "$($config.displayName -replace '\s','')-$($config.'@odata.type' -replace '#microsoft.graph.', '').json" | Remove-InvalidFileNameChars
    $config | ConvertTo-Json | Add-Content -Path (Join-Path $pwd $fileName)
}
