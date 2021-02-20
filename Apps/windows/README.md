# Windows Applications

## New-AdobeReaderPackage.ps1

Creates an Adobe Acrobat Reader DC package for Microsoft Intune:

* Downloads the latest version of Adobe Acrobat Reader DC to using [Evergreen](https://www.powershellgallery.com/packages/Evergreen/)
* Coverts the Reader installer into an intunewin package with the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
* Uploads the package into Intune to create a new application and assign to All Users as Available using the [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md) module

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
