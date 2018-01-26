<#
    .SYNOPSIS
        Downloads and installs the Microsoft Teams desktop client.

    .DESCRIPTION
        Downloads and installs the Microsoft Teams desktop client. Run in end-user's context.
        The Teams client does not come as an MSI; installing via PowerShell makes it easier to download and install for Windows 10 MDM.
        
    .NOTES
        Name: Install-MicrosoftTeams.ps1
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
#Requires -Version 3

# Variables
$VerbosePreference = "Continue"
$LogFile = "$env:ProgramData\stealthpuppy\Logs\$($MyInvocation.MyCommand.Name).log"
$Target = "$env:Temp"
$Arguments = "--silent"
$HttpRegEx = "^((http[s]?|ftp):\/)?\/?([^:\/\s]+)((\/\w+)*\/)([\w\-\.]+[^#?\s]+)(.*)?(#[\w\-]+)?$"
$Teams = "$env:LocalAppData\Microsoft\Teams\Update.exe"
Start-Transcript -Path $LogFile

# Set installer download URL based on processor architecture
Switch ((Get-WmiObject Win32_OperatingSystem).OSArchitecture) {
    "32-bit" { Write-Verbose -Message "32-bit processor"; $Url = "https://teams.microsoft.com/downloads/DesktopUrl?env=production&plat=windows&arch=x86" }
    "64-bit" { Write-Verbose -Message "64-bit processor"; $Url = "https://teams.microsoft.com/downloads/DesktopUrl?env=production&plat=windows&arch=x64" }
}

# Get Microsoft Teams installer for the current platform; Returns the URL to the installer
$RequestContent = (Invoke-WebRequest -Uri $Url).Content

# Check that the returned content is a URL and download the installer
If ($RequestContent -match $HttpRegEx) {
    $Installer = "$Target\$(Split-Path -Path $RequestContent -Leaf)"
    Write-Verbose -Message "Downloading $RequestContent to $Installer"
    Start-BitsTransfer -Source $RequestContent -Destination $Installer -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits
} Else {
    Write-Error -Message "Content returned from the Teams download site is not a valid URL."
    Write-Verbose -Message "Content returned: $RequestContent"
    Stop-Transcript
    Break
}

# Install the Microsoft Teams client
If (Test-Path $Installer) {
    Write-Verbose -Message "Running installer: $Installer"; Start-Process -FilePath $Installer -ArgumentList $Arguments -Wait
    Write-Verbose -Message "Removing file: $Installer"; Remove-Item -Path $Installer -Force

    # Detect that the Microsoft Teams client has been installed
    If (Test-Path -Path $Teams) {
        Write-Verbose -Message "Installed Microsoft Teams $((Get-ItemProperty -Path $Teams).VersionInfo.ProductVersion)"
    } Else {
        Write-Error -Message "Unable to find the Teams executable, assume installation failed."
    }

} Else {
    Write-Error -Message "Unable to find the Microsoft Teams installer. Download failed."
}

Stop-Transcript