# Apps

Scripts for installing various applications via PowerShell with Intune and Windows 10.

## Set-ChromeExtensions.ps1

Configures a set of Google Chrome browser extensions as a preference or enforce the list of extensions.

Extensions set as a preference will prompt the user to enable the extension when the user launches Chrome. If the extension is removed, Chrome will honour the end-user choice. If the extenion is enforced, then the extension is automatically approved and can't be removed.

The script will require 2 updates - modify the list of extensions, then comment out the code that either sets the preference or enforces the extensions.

Set the following when adding the script to Intune:
* Run this script using the logged on credentials - No
* Run script in 64 bit PowerShell Host - Yes

## Set-CitrixWorkspaceConfiguration.ps1

Configures Citrix Workspace app (or Receiver) with the corporate store (i.e. Workspace or StoreFront). Modify the URL, Store name and description to suit the target environment.

Set the following when adding the script to Intune:
* Run this script using the logged on credentials - No
* Run script in 64 bit PowerShell Host - Yes

## Uninstall-MicrosoftTeams.ps1

Uninstalls Teams from the target user's profile.

Set the following when adding the script to Intune:
* Run this script using the logged on credentials - Yes
* Run script in 64 bit PowerShell Host - Yes

## Install-CitrixReceiver.ps1 & Install-CitrixWorkspace.ps1

*Note*: It is now possible to install Citrix Workspace app from the Store or wrap Workspace app to deploy natively, so this script is no longer needed.

Downloads and installs the Win32/Desktop version of Citrix Receiver or Workspace app from the Citrix web site. Read details here: [Deploy Citrix Receiver to Windows 10 with Intune and PowerShell](https://stealthpuppy.com/deploy-citrix-receiver-intune/)

* Checks whether Receiver is already installed and if not or not the latest version, will download and install Receiver
* Removes the Citrix Receiver for Windows Store because the two can't exist
* Installs the .NET Framework 3.5, required by Receiver
* Downloads Receiver via BITS transfer; this should succeed, because the machine must have Internet access to receive the script from Intune; will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); likely won't support proxy servers
* Renamed Receiver installer to CitrixReceiverWeb.exe if $Rename is True. Enables suppression of Add Accounts window
* Installs Receiver with specific command line arguments
* Removes the installer and provides basic logging for troubleshooting
* Verbose output is enabled for running the script manually during testing

The $BaselineVersion paramter is used to determine whether Receiver should be installed/upgraded if an existing version is already installed. The script checks the local machine for versions earlier than $BaselineVersion and proceeds if it finds an earlier verion. At this time, you would need to update this value to get machines already on that version to upgrade.

If the script is run manually, the output should look like this:

![Output from a manual execution of the Install-CitrixReceiver.ps1 script](https://raw.githubusercontent.com/aaronparker/intune/master/Apps/img/CitrixReceiverPowerShellInstall.PNG)

Set the following when adding the script to Intune:
* Run this script using the logged on credentials - No
* Run script in 64 bit PowerShell Host - Yes

## Install-MicrosoftTeams.ps1

*Note*: It is now possible to install Teams as an MSI, wrap Teams to deploy natively or install it as a part of Office 365 ProPlus, so this script is no longer needed.

Downloads and installs the latest Microsoft Teams desktop client. Queries the downloads URL for the latest version, downloads and installs silently.

* Queries the current system for the processor architecture
* Requests the latest version from a download URL
* Downloads the latest Microsoft Teams desktop client and installs it silently
* Checks that the download has completed
* Logs the steps and the version installed

If the script is run manually, the output should look like this:

![Output from a manual execution of the Install-MicrosoftTeams.ps1 script](https://raw.githubusercontent.com/aaronparker/intune/master/Apps/img/TeamsPowerShellInstall.PNG)

Set the following when adding the script to Intune:
* Run this script using the logged on credentials - No
* Run script in 64 bit PowerShell Host - Yes
