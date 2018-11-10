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

# Start logging
$stampDate = Get-Date
$LogFile = "$env:ProgramData\Intune-PowerShell-Logs\Machine-Config-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Install .NET Framework 3.5
$state = Get-WindowsCapability -Online | Where-Object {($_.Name -like "NetFx3~~~~") -and ($_.State -eq "NotPresent")}
If ($state) {Add-WindowsCapability -Online -Name "NetFx3~~~~" -Verbose}

# Remove capabilities
<# $capabilities = @(  "Browser.InternetExplorer~~~~*", `
        "Media.WindowsMediaPlayer~~~~*", `
        "XPS.Viewer~~~~*") #>
$capabilities = @("XPS.Viewer~~~~*")
ForEach ($capability in $capabilities) {
    Get-WindowsCapability -Online | Where-Object {($_.Name -like $capability) -and `
        ($_.State -eq "Installed" )} | Remove-WindowsCapability -Online
}

# Remove other optional features
$features = @(  "WorkFolders-Client", `
        "Microsoft-Windows-Printing-XPSServices-Package", `
        "Printing-XPSServices-Features", `
        "MediaPlayback", `
        "FaxServicesClientPackage")
ForEach ($feature in $features) {
    Get-WindowsOptionalFeature -Online | Where-Object {($_.Name -like $feature) -and `
        ($_.State -eq "Enabled" )} | Disable-WindowsOptionalFeature -Online -NoRestart -Verbose
}

# Stop Logging
Stop-Transcript
