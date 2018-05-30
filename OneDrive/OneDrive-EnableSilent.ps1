# Requires -Version 2
<#
    .SYNOPSIS
        Configures the local machine with various tasks / features.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function New-RegValue {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)] $Key,
        [Parameter(Mandatory = $True)] $Value,
        [Parameter(Mandatory = $True)] $Data,
        [Parameter(Mandatory = $True)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        $Type
    )
    If (!(Test-Path $Key)) { New-Item -Path $Key -Force }
    New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
}

# Creates the SilentAccountConfig registry value for silent account config
# Creates the FilesOnDemandEnabled registry value to enabled Files On Demand for Windows 10 1709 and later
New-RegValue -Key "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Value "SilentAccountConfig" -Data "1" -Type "Dword" -Verbose
New-RegValue -Key "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Value "FilesOnDemandEnabled" -Data "1" -Type "Dword" -Verbose
