<#
    .SYNOPSIS
        Get sync folders for various sync solutions in Redirect-Folders.ps1.

    .NOTES
        Author: Aaron Parker
        Site: https://stealthpuppy.com
        Twitter: @stealthpuppy
#>

# Citrix ShareFile / Files sync folder
$SyncFolder = Get-ItemPropertyValue -Path 'HKCU:\Software\Citrix\ShareFile\Sync' -Name 'PersonalFolderRootLocation' -ErrorAction SilentlyContinue

# Citrix Files (Drive Mapper)
$filesRoot = Get-ItemPropertyValue -Path 'HKCU:\Software\Citrix\Citrix Files\RootFolders' -Name 'RootLocation' -ErrorAction SilentlyContinue
$SyncFolder = "$filesRoot\Personal Folders"

# Box Drive
$SyncFolder = (Resolve-Path (Join-Path $env:USERPROFILE "Box")).Path

# Dropbox Business
$json = Get-Content -Path "$env:LocalAppData\Dropbox\info.json" | ConvertFrom-Json -ErrorAction SilentlyContinue
$SyncFolder = $json.business.path
