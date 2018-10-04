# Requires -Version 2
<#
    .SYNOPSIS
        Creates the EnableADAL registry value for silent account config
        
    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function New-RegValue {
    Param (
        [Parameter(Mandatory = $True)]$Key,
        [Parameter(Mandatory = $True)]$Value,
        [Parameter(Mandatory = $True)]$Data,
        [Parameter(Mandatory = $True)][ValidateSet('Binary','ExpandString','String','Dword','MultiString','QWord')]$Type
    )
    If (!(Test-Path $Key)) { New-Item -Path $Key -Force }
    New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
}

New-RegValue -Key "HKCU:\SOFTWARE\Microsoft\OneDrive" -Value "EnableADAL" -Data "1" -Type "Dword"
