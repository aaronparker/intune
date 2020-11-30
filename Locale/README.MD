# Set Locale

Scripts to set regional and time zone settings. Can be deployed as PowerShell scripts or will work with Proactive Remediations.

Ensure that the appropriate Local Experience Pack (LXP) has been deployed from the Microsoft Store. For example, these scripts have been tested with en-AU regional settings on an en-US Windows 10 installation. The target machines have also receive the [English (United Kingdom) Local Experience Pack](https://www.microsoft.com/en-gb/p/english-united-kingdom-local-experience-pack/9nt52vq39bvn?activetab=pivot:overviewtab) which is used by English (Australia) language settings.

Proactive remediation scripts:

* `Detect-SystemLocale.ps1` - detect whether the system locale and regional settings are set to the desired values
* `Resolve-SystemLocale.ps1` - resolves the locale and regional settings to the desired values

Use the following script as a PowerShell script in Intune where the tenant is not licensed for Proactive Remediations

* `Set-CurrentUserLocale.ps1`
