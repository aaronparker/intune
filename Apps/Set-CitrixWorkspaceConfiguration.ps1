#Requires -Version 2
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Configures a store in the Citrix Workspace app. Works for Microsoft Store or Win32 version of the Workspace app.

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
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Ensure the SmartScreen key exists
$key = "HKLM:\SOFTWARE\Policies\Citrix\Receiver\Sites"

# Add a Citrix Cloud Workspace store (with Gateway service) to the Workspace app
Set-RegValue -Key $key -Value "STORE1" -Type String -Data "Store;https://customer.cloud.com#Store;On;Store description"

Stop-Transcript
