# Shortcut

Scripts to create a shortcut or remove target shortcuts. Can be used to create shortcuts (typcially to an application) in the Start menu / desktop etc. or remove shortcuts. Can also be used in Proactive remediations to remove shortcuts from target locations.

Proactive remediation scripts:

* `Detect-PublicDesktopShortcuts.ps1` - detect whether there are shortcuts on the Public Desktop: `C:\Users\Public\Desktop`
* `Resolve-PublicDesktopShortcuts.ps1` - removes shortcuts from the Public Desktop
* `Detect-DuplicateShortcuts.ps1` - detect duplicate Microsoft Edge and Teams shortcuts
* `Remediate-DuplicateShortcuts.ps1` - remove duplicate Microsoft Edge and Teams shortcuts


Use the following script as a PowerShell script in Intune where the tenant is not licensed for Proactive Remediations

* `Remove-PublicShortcuts.ps1`
* `New-Shortcut.ps1`
