# macOS Applications

Download the latest version of of a set of macOS apps with `Get-MacApps.ps1`

* Parameters:
  * `-Path` - A path to where the apps should be downloaded into
* Outputs a path to the downloaded  apps

Convert PKG files into intunemac format with `New-IntuneMac.ps1`

* Parameters:
  * `-Path` - A path to where the intunewin packages should be created
  * `-Packages` - Paths to the downloaded app packages. Takes pipeline input from `Get-MacApps.ps1`
