# Windows Applications

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

### Invoke Store updates

After the initial deployment, the Microsoft Store can take some time to update Universal Platform Apps. `Invoke-StoreUpdates.ps1` can be used to force the Store to download updates.
