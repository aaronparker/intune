<#
    .SYNOPSIS
        Download macOS apps and convert into an IntuneMac package
 
    .NOTES
        New-EvergreenIntuneMac.ps1
        Author: Aaron Parker
	    Twitter: @stealthpuppy
 
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Script run locally.")]
Param (
    [Parameter()]
    [System.String] $Path = "/Users/aaron/Temp/macOS-Apps"
)

# Turn off download progress for faster downloads; Enable verbose output
$ProgressPreference = "SilentlyContinue"
$VerbosePreference = "Continue"

# If we are running on macOS, then continue
If ($PSVersionTable.OS -like "Darwin*") {

    # Check the working folder
    If (Test-Path -Path $Path -IsValid) {
        If (!(Test-Path -Path $Path)) {
            try {
                New-Item -Path $Path -ItemType "Directory" 
            }
            catch {
                Write-Warning "Failed to validate path: $Path."
                throw $_
            }
        }
        
        #region Get latest IntuneAppUtil binary
        Write-Host "`n== IntuneAppUtil" -ForegroundColor "Cyan"
        $uri = "https://raw.githubusercontent.com/msintuneappsdk/intune-app-wrapping-tool-mac/v1.2/IntuneAppUtil"
        $binary = Join-Path -Path $Path -ChildPath (Split-Path -Path $uri -Leaf)
        If (!(Test-Path -Path $binary)) {
            try {
                Invoke-WebRequest -Uri $uri -OutFile $binary -UseBasicParsing
            }
            catch {
                Write-Warning "Failed to download: $uri."
                throw $_
            }
            If (Test-Path -Path $binary) {
                try {
                    chmod +x $binary
                }
                catch {
                    Write-Warning "Failed to set execute permission on: $binary."
                    throw $_
                }
            }
        }
        #endregion


        #region 1Password
        $app = "Agilebits 1Password"
        Write-Host "`n== $app" -ForegroundColor "Cyan"
        $update = "https://app-updates.agilebits.com/check/1/20.3.0/OPM7/en/70700010"
        try {
            $r = Invoke-RestMethod -Uri $update
        }
        catch {
            Write-Warning "Failed to query: $update."
            throw $_
        }
        try {
            $url = ($r.sources | Where-Object { $_.name -eq "AgileBits" }).url
            $uri = $url -replace "zip$", "pkg"
            $output = Join-Path -Path $Path -ChildPath (Split-Path -Path $uri -Leaf)
            Write-Host "$($app): $uri" -ForegroundColor "Cyan"
            Write-Host "$($app): $output" -ForegroundColor "Cyan"
            Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing
        }
        catch {
            Write-Warning "Failed to grab Pkg."
            throw $_
        }

        # Convert the Pkg to IntuneMac format
        If (Test-Path -Path $output) {
            . $binary -c $output -o $Path -v
        }
        #endregion


        #region Adobe Acrobat Reader DC
        $app = "Adobe Acrobat Reader DC"
        Write-Host "`n== $app" -ForegroundColor "Cyan"
        $update = "https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/reader/current_version.txt"
        try {
            $version = Invoke-RestMethod -Uri $update
        }
        catch {
            Write-Warning "Failed to query: $update."
            throw $_
        }

        # Download Acrobat Reader
        try {
            $verstring = $version -replace "\.", ""
            $uri = "https://ardownload2.adobe.com/pub/adobe/reader/mac/AcrobatDC/$verstring/AcroRdrDC_$($verstring)_MUI.dmg"
            $output = Join-Path -Path $Path -ChildPath (Split-Path $uri -Leaf)
            Write-Host "$($app): $uri" -ForegroundColor "Cyan"
            Write-Host "$($app): $version" -ForegroundColor "Cyan"
            Write-Host "$($app): $output" -ForegroundColor "Cyan"
            Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing
        }
        catch {
            Write-Warning "Failed to grab Pkg."
            throw $_
        }

        # Mount the Dmg file
        try {
            If (Test-Path -Path $output) {
                $RegEx = "\/Volumes.*"
                $mount = hdiutil attach $output
                $VolPath = [RegEx]::Match($mount, $RegEx).Captures.Groups[0].Value

                # Copy the Workspace app installer to the scratch directory, removing spaces from the file name
                $Package = Get-ChildItem -Path $VolPath -Filter "AcroRdr*.pkg" | Select-Object -First 1
                $NewPackage = (Join-Path -Path $Path -ChildPath ((Split-Path -Path $Package -Leaf) -replace " ", ""))
                Copy-Item -Path $Package.FullName -Destination $NewPackage
            }
        }
        catch {
            Write-Warning "Failed extract Pkg from Dmg."
            throw $_
        }

        # Unmount the Dmg
        hdiutil detach $VolPath

        # Convert the Pkg to IntuneMac format
        If (Test-Path -Path $NewPackage) {
            . $binary -c $NewPackage -o $Path -v -n $version
        }
        #endregion


        #region Citrix Workspace app (DMG)
        $app = "Citrix Workspace app"
        Write-Host "`n== $app" -ForegroundColor "Cyan"
        $update = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod/catalog_macos.xml"
        try {
            $r = Invoke-RestMethod -Uri $update
        }
        catch {
            Write-Warning "Failed to query: $update."
            throw $_
        }
        try {
            $leaf = ($r.Catalog.Installers | Where-Object { $_.name -eq "Receiver" }).Installer.DownloadURL
            $uri = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod$($leaf)"
            $output = Join-Path -Path $Path -ChildPath (Split-Path $uri -Leaf)
            Write-Host "$($app): $uri" -ForegroundColor "Cyan"
            Write-Host "$($app): $output" -ForegroundColor "Cyan"
            Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing
        }
        catch {
            Write-Warning "Failed to grab Pkg."
            throw $_
        }

        # Convert the Pkg to IntuneMac format
        If (Test-Path -Path $output) {
            . $binary -c $output -o $Path -v
        }
        #endregion


        #region Microsoft Teams
        $app = "Microsoft Teams"
        Write-Host "`n== $app" -ForegroundColor "Cyan"
        $update = "https://teams.microsoft.com/package/desktopclient/update/1.3.00.30874/osx/x64?ring=general&isDaemonUpdater=true"
        try {
            $r = Invoke-RestMethod -Uri $update
        }
        catch {
            Write-Warning "Failed to query: $update."
            throw $_
        }
        try {
            $output = Join-Path -Path $Path -ChildPath (Split-Path -Path $r.url -Leaf)
            $version = [RegEx]::Match($r.url, "(\d+(\.\d+){1,4})").Captures.Groups[0].Value
            Write-Host "$($app): $uri" -ForegroundColor "Cyan"
            Write-Host "$($app): $version" -ForegroundColor "Cyan"
            Write-Host "$($app): $output" -ForegroundColor "Cyan"
            Invoke-WebRequest -Uri $r.url -OutFile $output -UseBasicParsing
        }
        catch {
            Write-Warning "Failed to grab Pkg."
            throw $_
        }
        # Convert the Pkg to IntuneMac format
        If (Test-Path -Path $output) {
            . $binary -c $output -o $Path -v -n $version
        }
        #endregion


        #region Zoom Client
        $app = "Zoom"
        Write-Host "`n== $app" -ForegroundColor "Cyan"
        try {
            $uri = "https://zoom.us/client/latest/Zoom.pkg"
            $output = Join-Path -Path $Path -ChildPath (Split-Path -Path $uri -Leaf)
            Write-Host "$($app): $uri" -ForegroundColor "Cyan"
            Write-Host "$($app): $output" -ForegroundColor "Cyan"
            Invoke-WebRequest -Uri $uri -OutFile $output -UseBasicParsing
        }
        catch {
            Write-Warning "Failed to grab Pkg."
            throw $_
        }

        # Convert the Pkg to IntuneMac format
        If (Test-Path -Path $output) {
            . $binary -c $output -o $Path -v
        }
        #endregion
    }
}
Else {
    Write-Warning -Message "This script needs to be run on macOS to use the IntuneAppUtil wrapping tool."
}
