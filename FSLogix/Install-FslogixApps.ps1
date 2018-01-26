<#
    .SYNOPSIS
        Downloads and installs the FSLogix Apps agent.

    .DESCRIPTION
        Downloads and installs the FSLogix Apps agent. Checks whether the agent is already installed. Installs the agent if it is not installed or not up to date.
        Configures a scheduled task to download the FSLogix App Masking and Java Version Control rulesets from an Azure blog storage container.
        
    .NOTES
        Name: Install-FslogixApps.ps1
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
#Requires -Version 3

# Variables
$VerbosePreference = "Continue"
$LogFile = "$env:ProgramData\stealthpuppy\Logs\$($MyInvocation.MyCommand.Name).log"
$Target = "$env:SystemRoot\Temp"
$Arguments = "/install /quiet /norestart ProductKey=TRIAL-G6KID-WKRKO-J96IA-O9SB7"
Start-Transcript -Path $LogFile

# Set installer download URL based on processor architecture
Switch ((Get-WmiObject Win32_OperatingSystem).OSArchitecture) {
    "32-bit" { Write-Verbose -Message "32-bit processor"; $Url = "https://stlhppymdrn.blob.core.windows.net/fslogix-agent/x86/FSLogixAppsSetup.exe" }
    "64-bit" { Write-Verbose -Message "64-bit processor"; $Url = "https://stlhppymdrn.blob.core.windows.net/fslogix-agent/x64/FSLogixAppsSetup.exe" }
}

# Download FSLogix Agent installer; Get file info from the downloaded file to compare against what's installed
$Installer = Split-Path -Path $Url -Leaf
Write-Verbose -Message "Downloading $Url to $Target\$Installer"
Start-BitsTransfer -Source $Url -Destination "$Target\$Installer" -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits
$ProductVersion = (Get-ItemProperty -Path "$Target\$Installer").VersionInfo.ProductVersion
If ($ProductVersion) { Write-Verbose "Downloaded FSLogix Apps version: $ProductVersion." } Else { Write-Verbose "Unable to query downloaded FSLogix Apps version." }

# Determine whether FSLogix Agent is already installed
Write-Verbose -Message "Querying for installed FSLogix Apps version."
$Agent = Get-WmiObject -Class Win32_Product -ErrorAction Continue | Where-Object { $_.Name -Like "FSLogix Apps" } | Select-Object Name, Version
If ($Agent) { Write-Verbose "Found FSLogix Apps $($Agent.Version)." }

# Install the FSLogix Agent
If (Test-Path "$Target\$Installer") {

    # If installed version less than downloaded version, install the update
    If (!($Agent) -or ($Agent.Version -lt $ProductVersion)) {
        Write-Verbose -Message "Installing the FSLogix Agent $ProductVersion."; 
        Start-Process -FilePath "$Target\$Installer" -ArgumentList $Arguments -Wait
        Write-Verbose -Message "Deleting $Target\$Installer"; Remove-Item -Path "$Target\$Installer" -Force -ErrorAction Continue
        Write-Verbose -Message "Querying for installed FSLogix Agent."
        $Agent = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "FSLogix Apps" } | Select-Object Name, Version
        Write-Verbose -Message "Installed FSLogix Agent: $($Agent.Version)."
    } Else {

        # Skip install if agent already installed and up to date
        Write-Verbose "Skipping installation of the FSLogix Agent. Version $($Agent.Version) already installed."
    }
} Else {
    Write-Verbose "Unable to find the FSLogix Apps installer."
    # If we get here, it's possible the script couldn't download the installer
    # Delete script key under HKLM\SOFTWARE\Microsoft\IntuneManagementExtension to get script to re-run again in ~60 minutes
    $KeyParent = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Policies"
    $ScriptName = Split-Path -Path $MyInvocation.MyCommand.Name -Leaf
    $KeyPath = "$KeyParent\$($ScriptName.Split("_")[0])\$($ScriptName.Split("_")[1] -replace ".ps1")"
    If (Test-Path -Path $KeyPath) {
        Write-Verbose "Removing registry key to force script to re-run: $KeyPath"
        Remove-Item -Path $KeyPath -Force
    }
    Stop-Transcript
    Break
}

# Add configure scheduled task here.

Stop-Transcript