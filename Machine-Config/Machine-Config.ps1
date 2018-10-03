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
[CmdletBinding()]
Param (
    [Parameter()] $LogFile = "$env:ProgramData\stealthpuppy\Logs\$($MyInvocation.MyCommand.Name).log"
)

# Start logging
Start-Transcript -Path $LogFile

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

# Install .NET Framework 3.5
$State = Get-WindowsCapability -Online | Where-Object { $_.Name -like "NetFx3~~~~" -and $_.State -eq "NotPresent" }
If ($State) { Add-WindowsCapability -Online -Name "NetFx3~~~~" -Verbose }

# Remove capabilities
Get-WindowsCapability -Online | Where-Object { $_.Name -like "Browser.InternetExplorer~~~~*" } | Remove-WindowsCapability -Online
Get-WindowsCapability -Online | Where-Object { $_.Name -like "Media.WindowsMediaPlayer~~~~*" } | Remove-WindowsCapability -Online

# Remove other optional features
$Features = @("WorkFolders-Client", `
        "Internet-Explorer-Optional-amd64", `
        "Microsoft-Windows-Printing-XPSServices-Package", `
        "Printing-XPSServices-Features", `
        "WindowsMediaPlayer", `
        "FaxServicesClientPackage")
Disable-WindowsOptionalFeature -Online -FeatureName $Features -NoRestart -Verbose

# Stop Logging
Stop-Transcript
