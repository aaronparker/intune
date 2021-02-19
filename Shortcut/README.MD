# Shortcut

Scripts to create a shortcut or remove target shortcuts. Can be used to create shortcuts (typically to an application) in the Start menu / desktop etc. or remove shortcuts. Can also be used in Proactive remediations to remove shortcuts from target locations.

## Proactive remediation scripts

### Detect and remove Public desktop shortcuts

* `Detect-PublicDesktopShortcuts.ps1` - detect whether there are shortcuts on the Public Desktop: `C:\Users\Public\Desktop`
* `Remediate-PublicDesktopShortcuts.ps1` - removes shortcuts from the Public Desktop

Run with the following settings:

* `Run script in 64-bit PowerShell` - Yes
* `Run this script using the logged-on credentials` - No

### Detect and remove duplicate shortcuts

* `Detect-DuplicateShortcuts.ps1` - detect duplicate Microsoft Edge and Teams shortcuts
* `Remediate-DuplicateShortcuts.ps1` - remove duplicate Microsoft Edge and Teams shortcuts

Run with the following settings:

* `Run script in 64-bit PowerShell` - Yes
* `Run this script using the logged-on credentials` - Yes

When shortcuts are removed a notification will be shown to the user:

![Removed shortcuts notification](/Shortcut/img/removedshortcutsnotification.png)

## PowerShell scripts

Use the following script as a PowerShell script in Intune where the tenant is not licensed for Proactive Remediations

* `Remove-PublicShortcuts.ps1`
* `New-Shortcut.ps1`
