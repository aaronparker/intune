# Requires -Version 2
# Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Enables Windows SmartScreen.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function Set-RegValue {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)] $Key,
        [Parameter(Mandatory = $True)] $Value,
        [Parameter(Mandatory = $True)] $Data,
        [Parameter(Mandatory = $True)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        $Type
    )
    try {
        If (!(Test-Path $Key)) {
            New-Item -Path $Key -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key with error $_."
        Break
    }
    finally {
        New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
    }
}

$stampDate = Get-Date
$LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\Set-SmartScreen-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Ensure the SmartScreen key exists
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost"

# Set SmartScreen for Microsoft Store apps to Warn
Set-RegValue -Key $key -Value "EnableWebContentEvaluation" -Type DWord -Data 1
Set-RegValue -Key $key -Value "PreventOverride" -Type DWord -Data 0

Stop-Transcript
