# Apps
Scripts for installing various applications via PowerShell with Intune and Windows 10.

## Install-CitrixReceiver.ps1
Downloads and installs the Win32/Desktop version of Citrix Receiver from the Citrix web site. Read details here: [Deploy Citrix Receiver to Windows 10 with Intune and PowerShell](https://stealthpuppy.com/deploy-citrix-receiver-intune/)

* Checks whether Receiver is already installed and if not or not the latest version, will download and install Receiver.
* Removes the Citrix Receiver for Windows Store because the two can't exist
* Installs the .NET Framework 3.5, required by Receiver
* Downloads Receiver via BITS transfer; this should succeed, because the machine must have Internet access to receive the script from Intune; will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); likely won't support proxy servers
* Installs Receiver with specific command line arguments
* Removes the installer and provides basic logging for troubleshooting.
