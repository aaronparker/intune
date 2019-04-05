<#
    Compare folder containing exported Intune configurations.
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $PreviousConfigurationPath,

    [Parameter()]
    [string] $NewConfigurationPath = $pwd
)

#region Functions
Function Compare-IntuneConfig {
    <#
        .SYNOPSIS
            Compare two Intune configuration files for changes.
        
        .DESCRIPTION
            Compare two Intune configuration files for changes. The DifferenceFilePath should point to the latest Intune configuration file, as it may contain new properties.
        
        .PARAMETER ReferenceFilePath
            Any exported Intune configuration file.
        
        .PARAMETER DifferenceFilePath
            Latest exported Intune configuration file, that matches the Intune configuration (e.g. Device Compliance Policy, Device Configuration Profile or Device Management Script).
        
        .EXAMPLE
            Compare-IntuneConfig -ReferenceFilePath '.\Old\WindowsEndpointProtection.json' -DifferenceFilePath '.\New\WindowsEndpointProtection.json'
        
        .NOTES
            Author: John Seerden
            Link: https://github.com/jseerden/IntuneBackupAndRestore/blob/master/IntuneBackupAndRestore/Public/Compare-IntuneBackupFile.ps1
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string] $ReferenceFilePath,

        [Parameter(Mandatory = $true)]
        [string] $DifferenceFilePath
    )

    try {
        $backupFile = Get-Content -Path $ReferenceFilePath -Raw -ErrorAction Continue
    }
    catch {
        Write-Warning -Message "Failed to read ReferenceFile: $ReferenceFilePath"
    }
    try {
        $backupFile = $backupFile | ConvertFrom-Json
    }
    catch {
        Write-Warning -Message "Failed to convert to JSON: $ReferenceFilePath"
    }
    try {
        $latestBackupFile = Get-Content -Path $DifferenceFilePath -Raw -ErrorAction Continue
    }
    catch {
        Write-Warning -Message "Failed to read DifferenceFile: $DifferenceFilePath"
    }
    try {
        $latestBackupFile = $latestBackupFile | ConvertFrom-Json
    }
    catch {
        Write-Warning -Message "Failed to convert to JSON: $DifferenceFilePath"
    }

    $backupComparison = ForEach ($latestBackupFileProperty in $latestBackupFile.PSObject.Properties.Name) {
        $compareBackup = Compare-Object -ReferenceObject $backupFile -DifferenceObject $latestBackupFile -Property $latestBackupFileProperty
        If ($compareBackup.SideIndicator) {
            # If the property exists in both Intune configuration files
            If ($latestBackupFileProperty -notmatch [RegEx]"PSParentPath|PSPath") {
                If ($backupFile.$latestBackupFileProperty) {
                    [PSCustomObject][Ordered]@{
                        'Config'   = [io.path]::GetFileNameWithoutExtension($DifferenceFilePath)
                        'Property' = $latestBackupFileProperty
                        'OldValue' = $backupFile.$latestBackupFileProperty
                        'NewValue' = $latestBackupFile.$latestBackupFileProperty
                    }
                }
                # If the property only exists in the latest Intune configuration files
                Else {
                    [PSCustomObject][Ordered]@{
                        'Config'   = [io.path]::GetFileNameWithoutExtension($DifferenceFilePath)
                        'Property' = $latestBackupFileProperty
                        'OldValue' = $null
                        'NewValue' = $latestBackupFile.$latestBackupFileProperty
                    }
                }
            }
        }
    }

    Write-Output $backupComparison
}
#endregion

# Resolve paths
$PreviousConfigurationPath = Resolve-Path $PreviousConfigurationPath
$NewConfigurationPath = Resolve-Path $NewConfigurationPath

$previousConfigurations = Get-ChildItem -Path $PreviousConfigurationPath -Recurse -Include *.json
$newConfigurations = Get-ChildItem -Path $NewConfigurationPath -Recurse -Include *.json
ForEach ($prevFile in $previousConfigurations) {
    $newFile = $newConfigurations | Where-Object { $_.Name -eq $prevFile.Name }
    Write-Verbose "Comparing $prevFile with $newFile"
    Compare-IntuneConfig -ReferenceFilePath $prevFile -DifferenceFilePath $newFile
}
