# Windows Applications

## New-AdobeReaderPackage.ps1

Creates an Adobe Acrobat Reader DC package for Microsoft Intune:

* Downloads the latest version of Adobe Acrobat Reader DC using [Evergreen](https://www.powershellgallery.com/packages/Evergreen/)
* Coverts the Reader installer into an `Intunewin` package with the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
* Uploads the package into Intune to create a new application and assign to `All Users` as `Available` using the [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md) module

## New-MicrosoftVcRedistPackage.ps1

Creates a Microsoft Visual C++ Redistributable packages for Microsoft Intune:

* Downloads the latest version Microsoft Visual C++ Redistributables using [VcRedist](https://www.powershellgallery.com/packages/VcREdist/)
* Coverts the Visual C++ Redistributable installer into an `Intunewin` package with the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
* Uploads the package into Intune to create a new application and assign to `All Devices` as `Required` using the [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md) module

## Set-ChromeExtensions.ps1

Configures a set of Google Chrome browser extensions as a preference or enforce the list of extensions.

Extensions set as a preference will prompt the user to enable the extension when the user launches Chrome. If the extension is removed, Chrome will honour the end-user choice. If the extension is enforced, then the extension is automatically approved and can't be removed.

The script will require 2 updates - modify the list of extensions, then comment out the code that either sets the preference or enforces the extensions.

Set the following when adding the script to Intune:

* Run this script using the logged on credentials - No
* Run script in 64 bit PowerShell Host - Yes

## Uninstall-MicrosoftTeams.ps1

Uninstalls Teams from the target user's profile.

Set the following when adding the script to Intune:

* Run this script using the logged on credentials - Yes
* Run script in 64 bit PowerShell Host - Yes

## Universal Platform Apps scripts

### Remove Appx Apps

Note: `Remove-AppxApps.ps1` can be found here: [https://github.com/aaronparker/image-customise/](https://github.com/aaronparker/image-customise/)

These scripts remove various AppX / UWP / Windows Store applications from an online image. Windows 10 devices come with various built-in AppX applications. While these applications can be targeted for removal by MDM tools, they are often not removed in a timely manner. Additionally, some AppX applications are not available in the Microsoft Store for Business and therefore cannot be targeted.

These scripts will remove AppX provisioned in the system and user contexts. Apps can be targeted with a blacklist or a whitelist of applications. Take care if using the whitelist approach so that a desktop is not put into an unusable state by removing required apps.

`Remove-AppxApps.ps1` can be run elevated to remove apps from the system or non-elevated to remove apps from the current user profile only.

### Invoke Store updates

After the initial deployment, the Microsoft Store can take some time to update Universal Platform Apps. `Invoke-StoreUpdates.ps1` can be used to force the Store to download updates.
