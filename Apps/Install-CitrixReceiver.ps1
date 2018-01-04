<#
.SYNOPSIS
    Downloads and installs Citrix Receiver (Win32/Desktop version) for full functionality.
    Allows for Receiver installation via a PowerShell script to Windows 10 with Microsoft Intune.
    Provides basic error checking and outputs to a log file; Add -Verbose for running manually.
#>

# Variables
$Url = "https://downloadplugins.citrix.com/Windows/CitrixReceiver.exe"
$Target = "$env:SystemRoot\Temp\CitrixReceiver.exe"
$LogFile = "$env:SystemRoot\Temp\CitrixReceiver.log"
$BaselineVersion = [System.Version]"4.10.0.0"
$Arguments = "/AutoUpdateCheck=auto /AutoUpdateStream=Current /DeferUpdateCount=5 /AURolloutPriority=Medium /NoReboot /Silent EnableCEIP=False"

# Determine whether Receiver is already installed
$Receiver = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Receiver Inside*" }

# If Receiver is not installed, download and install; or installed Receiver less than current proceed with install
If (!($Receiver) -or ($Receiver.Version -lt $BaselineVersion)) {
    
    # Win32 Receiver and Receiver for Store can't coexist. Remove Store version if installed
    # https://docs.citrix.com/en-us/receiver/windows-store/current-release/install.html
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "D50536CD.CitrixReceiver" } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue -ErrorVariable $ErrorRemoveAppx -Verbose
    If ($ErrorRemoveAppx) { $ErrorRemoveAppx | Out-File -FilePath $LogFile -Append }

    # Install the .NET Framework 3.5. This will download the .NET Framework from the Internet
    # Citrix Receiver system requirements: https://docs.citrix.com/en-us/receiver/windows/current-release/system-requirements.html
    If ((Get-WindowsCapability -Online -Name "NetFx3~~~~").State -ne "Installed") {
        Add-WindowsCapability -Online -Name "NetFx3~~~~" -ErrorAction SilentlyContinue -ErrorVariable $ErrorAddDotNet -Verbose
        If ($ErrorAddDotNet) { $ErrorAddDotNet | Out-File -FilePath $LogFile -Append }
    }
        
    # Delete the installer if it exists, so that we don't have issues downloading
    If (Test-Path $Target) { Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue -Verbose }

    # Download Citrix Receiver locally; This should succeed, because the machine must have Internet access to receive the script from Intune
    # Will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); Likely won't support proxy servers
    Start-BitsTransfer -Source $Url -Destination $Target -Priority High -TransferPolicy Always -ErrorAction SilentlyContinue -ErrorVariable $ErrorBits -Verbose
    If ($ErrorBits) { $ErrorBits | Out-File -FilePath $LogFile -Append }

    # Install Citrix Receiver; wait 3 seconds to ensure finished; remove installer
    If (Test-Path $Target) {
        Start-Process -FilePath $Target -ArgumentList $Arguments -Wait
        Start-Sleep -Seconds 3
        Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue -Verbose
        $Receiver = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Receiver Inside*" } | Select-Object Name, Version
        "[$(Get-Date)] Installed Citrix Receiver: $($Receiver.Version)" | Out-File -FilePath $LogFile -Append
    } Else {
        $ErrorInstall = "Citrix Receiver installer path at $Target not found."
        $ErrorInstall | Out-File -FilePath $LogFile -Append
    }

    # Intune shows basic deployment status in the Overview blade of the PowerShell script properties
    Return @($ErrorRemoveAppx, $ErrorAddDotNet, $ErrorBits, $ErrorInstall)
}
