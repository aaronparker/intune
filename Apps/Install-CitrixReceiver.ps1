<#
.SYNOPSIS
    Downloads and installs Citrix Receiver.
    Intended to run a script via Intune.
#>

# Variables
$Url = "https://downloadplugins.citrix.com/Windows/CitrixReceiver.exe"
$Target = "$env:SystemRoot\Temp\CitrixReceiver.exe"
$CheckVersion = [System.Version]"4.10.0.0"

# If Receiver is already installed, skip download and install
If (!(Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Receiver Inside*" -And $_.Version -lt $CheckVersion })) {

    # Win32 Receiver and Receiver for Store can't coexist. Remove Store version if installed
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "D50536CD.CitrixReceiver" } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue -ErrorVariable $ErrorRemoveAppx

    # Citrix Receiver system requirements: https://docs.citrix.com/en-us/receiver/windows/current-release/system-requirements.html
    # Install the .NET Framework 3.5. This will download the .NET Framework from the Internet
    If ((Get-WindowsCapability -Online -Name "NetFx3~~~~").State -ne "Installed") {
        Add-WindowsCapability -Online -Name "NetFx3~~~~" -ErrorAction SilentlyContinue -ErrorVariable $ErrorAddDotNet
    }
    
    # Delete the installer if it exists, so that we don't have issues downloading
    If (Test-Path $Target) { Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue }

    # Download Citrix Receiver locally
    Start-BitsTransfer -Source $Url -Destination $Target -ErrorAction SilentlyContinue -ErrorVariable $ErrorBits

    # Install Citrix Receiver
    If (Test-Path $Target) {
        Start-Process -FilePath $Target -ArgumentList "/AutoUpdateCheck=auto /AutoUpdateStream=Current /DeferUpdateCount=5 /AURolloutPriority=Medium /NoReboot /Silent EnableCEIP=False" -Wait
        Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
    }

    @($ErrorRemoveAppx, $ErrorAddDotNet, $ErrorBits) | Out-File "$env:SystemRoot\Temp\CitrixReceiver.log"
    Return @($ErrorRemoveAppx, $ErrorAddDotNet, $ErrorBits)
}
