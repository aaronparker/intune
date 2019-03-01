#Requires -Version 2
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Configures Google Chrome extensions as preferences or enforced.

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
        [Parameter(Mandatory = $False)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        $Type = "String"
    )
    try {
        If (!(Test-Path -Path $Key)) {
            New-Item -Path $Key -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key with error $_."
        Break
    }
    finally {
        New-ItemProperty -Path $Key -Name $value -Value $Data -PropertyType $Type -Force
    }
}


# Log file
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Extensions
$extensions = @{
    # "Windows Defender Browser Protection" = "bkbeeeffjjeopflfhgeknacdieedcoml"
    "My Apps Secure Sign-in Extension" = "ggjhpefgjjfobnfoldnjipclpcfbgbhl"
    "Web Activities"                   = "eiipeonhflhoiacfbniealbdjoeoglid"
    "Office Online"                    = "ndjpnladcallmjemlbaebfadecfhkepb"
}


# Chrome extensions as Preferences
$regKey = 'HKLM:\SOFTWARE\WOW6432Node\Google\Chrome\Extensions'
$value = 'update_url'
$data = 'https://clients2.google.com/service/update2/crx'
ForEach ($ext in $extensions.Values) {
    Set-RegValue -Key "$regKey\$ext" -Value $value -Data $data
}

<#
# Enforce Chrome extensions
$regKey = 'HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist'
If (!(Test-Path -Path $regKey)) {
    New-Item -Path $regKey -Force -ErrorAction SilentlyContinue
}
$existingValues = (Get-Item -Path $regKey).Property
$value = [int]$existingValues[$existingValues.Count - 1] + 1
ForEach ($ext in $extensions.Values) {
    $existingValues = (Get-Item -Path $regKey).Property
    $value = [int]$existingValues[$existingValues.Count - 1] + 1
    Set-RegValue -Key $regKey -Value $value -Data "$ext;https://clients2.google.com/service/update2/crx"
}
#>

Stop-Transcript
