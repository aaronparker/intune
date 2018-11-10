# Requires -Version 3
<#
.SYNOPSIS
    Downloads and installs Citrix Receiver (Win32/Desktop version) for full functionality.
    Allows for Receiver installation via a PowerShell script to Windows 10 with Microsoft Intune.
    Provides basic error checking and outputs to a log file; Add -Verbose for running manually.

.NOTES
    Name: Install-CitrixReceiver.ps1
    Author: Aaron Parker
    Site: https://stealthpuppy.com
    Twitter: @stealthpuppy
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
Param (
    [Parameter()]$Url = "https://downloadplugins.citrix.com/Windows/CitrixReceiver.exe",
    [Parameter()]$Target = "$env:SystemRoot\Temp\CitrixReceiver.exe",
    [Parameter()]$BaselineVersion = [System.Version]"4.10.1.0",
    [Parameter()]$TargetWeb = "$env:SystemRoot\Temp\CitrixReceiverWeb.exe",
    [Parameter()]$Rename = $True,
    [Parameter()]$Arguments = '/AutoUpdateCheck=auto /AutoUpdateStream=Current /DeferUpdateCount=5 /AURolloutPriority=Medium /NoReboot /Silent EnableCEIP=False',
    [Parameter()]$VerbosePreference = "Continue"
)

$stampDate = Get-Date
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\Install-CitrixReceiver-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

# Determine whether Receiver is already installed
Write-Verbose -Message "Querying for installed Receiver version."
$Receiver = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Receiver Inside*" }

# If Receiver is not installed, download and install; or installed Receiver less than current proceed with install
If (!($Receiver) -or ($Receiver.Version -lt $BaselineVersion)) {
    
    # Win32 Receiver and Receiver for Store can't coexist. Remove Store version if installed
    # https://docs.citrix.com/en-us/receiver/windows-store/current-release/install.html
    Write-Verbose -Message "Querying for Receiver for Store."
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "D50536CD.CitrixReceiver" } | Remove-AppxPackage -AllUsers -ErrorAction Continue -ErrorVariable $ErrorRemoveAppx -Verbose

    # Install the .NET Framework 3.5. This will download the .NET Framework from the Internet
    # Citrix Receiver system requirements: https://docs.citrix.com/en-us/receiver/windows/current-release/system-requirements.html
    Write-Verbose -Message "Querying for required .NET Framework."
    If ((Get-WindowsCapability -Online -Name "NetFx3~~~~").State -ne "Installed") {
        Write-Verbose -Message "Installing .NET Framework 3.5"
        Add-WindowsCapability -Online -Name "NetFx3~~~~" -ErrorAction Continue -ErrorVariable $ErrorAddDotNet -Verbose
    }

    # Delete the installer if it exists, so that we don't have issues downloading
    If (Test-Path $Target) { Write-Verbose -Message "Deleting $Target"; Remove-Item -Path $Target -Force -ErrorAction Continue -Verbose }

    # Download Citrix Receiver locally; This should succeed, because the machine must have Internet access to receive the script from Intune
    # Will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); Likely won't support proxy servers
    Write-Verbose -Message "Downloading Citrix Receiver from $Url"
    Start-BitsTransfer -Source $Url -Destination $Target -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits -Verbose
    
    # If $Rename is True, rename the executable. Renaming to CitrixReceiverWeb.exe supresses the Add Account window without having to set /ALLOWADDSTORE=N
    If ($Rename) { Write-Verbose -Message "Renaming $Target to $TargetWeb"; Rename-Item -Path $Target -NewName $TargetWeb; $Target = $TargetWeb }

    # Install Citrix Receiver; wait 3 seconds to ensure finished; remove installer
    If (Test-Path $Target) {
        Write-Verbose -Message "Installing Citrix Receiver."; Start-Process -FilePath $Target -ArgumentList $Arguments -Wait
        Write-Verbose -Message "Sleeping for 3 seconds."; Start-Sleep -Seconds 3
        Write-Verbose -Message "Deleting $Target"; Remove-Item -Path $Target -Force -ErrorAction Continue -Verbose
        Write-Verbose -Message "Querying for installed Receiver version."
        $Receiver = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Receiver Inside*" } | Select-Object Name, Version
        Write-Verbose -Message "Installed Citrix Receiver: $($Receiver.Version)."
    } Else {
        $ErrorInstall = "Citrix Receiver installer path at $Target not found."
    }

    # Intune shows basic deployment status in the Overview blade of the PowerShell script properties
    @($ErrorRemoveAppx, $ErrorAddDotNet, $ErrorBits, $ErrorInstall) | Write-Output
} Else {
    Write-Verbose "Skipping Receiver installation. Installed version is $($Receiver.Version)"
}

Stop-Transcript
