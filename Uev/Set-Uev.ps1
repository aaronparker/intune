#Requires -PSEdition Desktop
#Requires -Version 3
#Requires -RunAsAdministrator
<#PSScriptInfo

.VERSION 1.0.0

.GUID c4881872-2b2b-4711-905a-5dae9a19eafd

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2019, Aaron Parker. All rights reserved.

.TAGS UE-V Windows10 Profile-Container

.DESCRIPTION Enables and configures the UE-V service on an Intune managed Windows 10 PC

.LICENSEURI https://github.com/aaronparker/Intune-Scripts/blob/master/LICENSE

.PROJECTURI https://github.com/aaronparker/Intune-Scripts/tree/master/Redirections

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    - May 2019, 1.0.0, Initial version

.PRIVATEDATA
#>
<#
    .SYNOPSIS
        Enables and configures the UE-V service on an Intune managed Windows 10 PC

    .DESCRIPTION
        

    .PARAMETER Redirections

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com

    .EXAMPLE
        Set-Uev.ps1
#>
[CmdletBinding(SupportsShouldProcess = $True, HelpURI = "")]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $false)]
    [string] $Uri
)

# If the UEV module is installed, enable the UEV service
If (Get-Module -ListAvailable -Name UEV) {
    Import-Module -Name UEV

    # Enable the UE-V service
    $status = Get-UevStatus
    If ($status.UevEnabled -ne $True) {
        Write-Verbose -Message "Enabling the UE-V service."
        Enable-Uev
        $status = Get-UevStatus
    }
    Else {
        Write-Verbose "UE-V service is enabled."
    }
    If ($status.UevRebootRequired -eq $True) {
        Write-Warning "Reboot required to enable the UE-V service."
    }
}
Else {
    Write-Error "UEV module not installed."
}

# Determine the UEV settings storage path in the OneDrive folder
If (Test-Path -Path "env:OneDriveCommercial") {
    $settingsStoragePath = "%OneDriveCommercial%"
    Write-Verbose -Message "UE-V Settings Storage Path is $settingsStoragePath."
}
ElseIf (Test-Path -Path "env:OneDrive") {
    $settingsStoragePath = "%OneDrive%"
    Write-Verbose -Message "UE-V Settings Storage Path is $settingsStoragePath."
}
Else {
    Write-Warning "OneDrive path not found."
}

# Set the UEV settings
If ($status.UevEnabled -eq $True) {
    $UevParams = @{
        Computer                            = $True
        EnableDontSyncWindows8AppSettings   = $True
        EnableSyncUnlistedWindows8Apps      = $True
        EnableSettingsImportNotify          = $True
        DisableSyncProviderPing             = $True
        SettingsStoragePath                 = $settingsStoragePath
        # SettingsTemplateCatalogPath        = ""
        EnableSync                          = $True
        SyncMethod                          = "External"
        EnableWaitForSyncOnApplicationStart = $False
        EnableWaitForSyncOnLogon            = $False
        EnableFirstUseNotification          = $True
        EnableTrayIcon                      = $True
    }
    Set-UevConfiguration @UevParams
}

# Inbox templates
$inboxTemplatesSrc = "$env:ProgramData\Microsoft\UEV\InboxTemplates"
$inboxTemplates = Get-ChildItem -Path $inboxTemplatesSrc -Filter "*.xml" | Select-Object -Property FullName
ForEach ($template in $inboxTemplates) {
    Register-UevTemplate -Path $template
}
