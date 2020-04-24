# Universal Platform Apps scripts

## Remove Appx Apps

These scripts remove various AppX / UWP / Windows Store applications from an online image. Windows 10 devices come with various built-in AppX applications. While these applications can be targeted for removal by MDM tools, they are often not removed in a timely manner. Additionally, some AppX applications are not available in the Microsoft Store for Business and therefore cannot be targeted.

These scripts will remove AppX provisioned in the system and user contexts. Apps can be targeted with a blacklist or a whitelist of applications. Take care if using the whitelist approach so that a desktop is not put into an unusable state by removing required apps.

`Remove-AppxApps.ps1` can be run elevated to remove apps from the system or non-elevated to remove apps from the current user profile only.

## Invoke Store updates

After the initial deployment, the Microsoft Store can take some time to update Universal Platform Apps. `Invoke-StoreUpdates.ps1` can be used to force the Store to download updates.
