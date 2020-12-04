<#
    .SYNOPSIS
        Download macOS apps and convert into an IntuneMac package
 
    .NOTES
        ConvertTo-PkgIntuneMac.ps1
        AUTHOR: Aaron Parker
	    TWITTER: @stealthpuppy
 
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
Param ()

# Turn off download progress for faster downloads
$ProgressPreference = "SilentlyContinue"

# Working folder
$scratch = "/Users/aaron/Projects/macOS-Apps"
If (!(Test-Path -Path $scratch)) { New-Item -Path $scratch -ItemType "Directory" }

# Get latest IntuneAppUtil binary
$uri = "https://raw.githubusercontent.com/msintuneappsdk/intune-app-wrapping-tool-mac/v1.2/IntuneAppUtil"
$binary = Join-Path -Path $scratch -ChildPath (Split-Path -Path $uri -Leaf)
If (!(Test-Path -Path $binary)) {
    Invoke-WebRequest -Uri $uri -OutFile $binary -UseBasicParsing
    chmod +x $binary
}


#region Microsoft Teams
# Note: URI is likely to need updating to the latest version
$uri = "https://statics.teams.cdn.office.net/production-osx/1.3.00.30874/Teams_osx.pkg"
$output = Join-Path -Path $scratch -ChildPath (Split-Path -Path $uri -Leaf)
$version = "1.3.00.30874"

# Download Teams
Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing

# Convert the PKG to INTUNEMAC
. $binary -c $output -o $scratch -v -n $version
#endregion


#region Zoom Client
$uri = "https://zoom.us/client/latest/Zoom.pkg"
$output = Join-Path -Path $scratch -ChildPath (Split-Path -Path $uri -Leaf)

# Download Zoom
Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing

# Convert the PKG to INTUNEMAC
. $binary -c $output -o $scratch -v
#endregion


#region Citrix Workspace app (DMG)
# Note: URI is likely to need updating to the latest version 
$uri = "https://downloads.citrix.com/18878/CitrixWorkspaceApp.dmg?__gda__=1607056590_b0f473aea6131831610dc5115fa62ac4"
$output = Join-Path -Path $scratch -ChildPath (Split-Path $uri -Leaf).Split("?")[0]

# Download Workspace app
Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing

# Mount the DMG file
$RegEx = "\/Volumes.*"
$mount = hdiutil attach $output
$VolPath = [RegEx]::Match($mount, $RegEx).Captures.Groups[0].Value

# Copy the Workspace app installer to the scratch directory, removing spaces from the file name
$Package = Get-ChildItem -Path $VolPath -Filter "Install Citrix Workspace.pkg" | Select-Object -First 1
$NewPackage = (Join-Path -Path $scratch -ChildPath ((Split-Path -Path $Package -Leaf) -replace " ", ""))
Copy-Item -Path $Package.FullName -Destination $NewPackage

# Unmount the DMG
hdiutil detach $VolPath

# Convert the PKG to INTUNEMAC
. $binary -c $NewPackage -o $scratch -v
#endregion


#region Adobe Acrobat Reader DC
# Note: URI is likely to need updating to the latest version 
$uri = "https://ardownload2.adobe.com/pub/adobe/reader/mac/AcrobatDC/2001320064/AcroRdrDC_2001320064_MUI.dmg"
$output = Join-Path -Path $scratch -ChildPath (Split-Path $uri -Leaf).Split("?")[0]

# Download Acrobat Reader
Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing

# Mount the DMG file
$RegEx = "\/Volumes.*"
$mount = hdiutil attach $output
$VolPath = [RegEx]::Match($mount, $RegEx).Captures.Groups[0].Value

# Copy the Workspace app installer to the scratch directory, removing spaces from the file name
$Package = Get-ChildItem -Path $VolPath -Filter "AcroRdr*.pkg" | Select-Object -First 1
$NewPackage = (Join-Path -Path $scratch -ChildPath ((Split-Path -Path $Package -Leaf) -replace " ", ""))
Copy-Item -Path $Package.FullName -Destination $NewPackage

# Unmount the DMG
hdiutil detach $VolPath

# Convert the PKG to INTUNEMAC
. $binary -c $NewPackage -o $scratch -v
#endregion


#region 1Password
$uri = "https://c.1password.com/dist/1P/mac7/1Password-7.7.pkg"
$output = Join-Path -Path $scratch -ChildPath (Split-Path -Path $uri -Leaf)

# Download Zoom
Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing

# Convert the PKG to INTUNEMAC
. $binary -c $output -o $scratch -v
#endregion
