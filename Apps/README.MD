# Apps
Scripts for installing various applications via PowerShell with Intune and Windows 10.

## Install-CitrixReceiver.ps1
Downloads and installs the Win32/Desktop version of Citrix Receiver from the Citrix web site. Read details here: [Deploy Citrix Receiver to Windows 10 with Intune and PowerShell](https://stealthpuppy.com/deploy-citrix-receiver-intune/)

* Checks whether Receiver is already installed and if not or not the latest version, will download and install Receiver.
* Removes the Citrix Receiver for Windows Store because the two can't exist
* Installs the .NET Framework 3.5, required by Receiver
* Downloads Receiver via BITS transfer; this should succeed, because the machine must have Internet access to receive the script from Intune; will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); likely won't support proxy servers
* Renamed Receiver installer to CitrixReceiverWeb.exe if $Rename is True. Enables suppression of Add Accounts window
* Installs Receiver with specific command line arguments
* Removes the installer and provides basic logging for troubleshooting
* Verbose output is enabled for running the script manually during testing

The $BaselineVersion paramter is used to determine whether Receiver should be installed/upgraded if an existing version is already installed. The script checks the local machine for versions earlier than $BaselineVersion and proceeds if it finds an earlier verion. At this time, you would need to update this value to get machines already on that version to upgrade.

If the script is run manually, the output should look like this:

![Output from a manual execution of the Install-CitrixReceiver.ps1 script](https://raw.githubusercontent.com/aaronparker/intune/blob/master/Apps/img/CitrixReceiverPowerShellInstall.PNG)
