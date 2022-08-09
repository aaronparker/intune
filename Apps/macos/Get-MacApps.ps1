<#
    .SYNOPSIS
        Download macOS apps for importing into Intune

    .NOTES
        Get-MacApps.ps1
        Author: Aaron Parker
	    Twitter: @stealthpuppy

    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Script run locally.")]
param (
    [Parameter()]
    [ValidateScript({ if (Test-Path -Path $Path) { $true } else { throw [System.IO.FileNotFoundException] } })]
    [System.String] $Path = "/Users/aaron/Temp/macOS-Apps"
)

# Test path
if (Test-Path -Path $Path -IsValid) {
    if (!(Test-Path -Path $Path)) {
        try {
            New-Item -Path $Path -ItemType "Directory" | Out-Null
        }
        catch {
            throw $_
        }
    }
}
else {
    throw "$Path is not a valid path."
}

#region Functions
function Resolve-SystemNetWebRequest ($Uri) {
    try {
        $httpWebRequest = [System.Net.WebRequest]::Create($Uri)
        $httpWebRequest.MaximumAutomaticRedirections = 3
        $httpWebRequest.AllowAutoRedirect = $true
        $httpWebRequest.UseDefaultCredentials = $true
        $webResponse = $httpWebRequest.GetResponse()
    }
    catch {
        throw $_
    }
    finally {
        if ($webResponse) {
            Write-Output -InputObject $webResponse.ResponseUri.AbsoluteUri
            $webResponse.Dispose()
        }
    }
}

function Save-File ($Path, $Object) {
    $ProgressPreference = "SilentlyContinue"
    foreach ($item in $Object) {
        $OutFile = $(Join-Path -Path $Path $(Split-Path -Path $item.Uri -Leaf))
        if (Test-Path -Path $OutFile) {
            Write-Output -InputObject $OutFile
        }
        else {
            try {
                $params = @{
                    Uri             = $item.Uri
                    OutFile         = $OutFile
                    UseBasicParsing = $true
                    ErrorAction     = "SilentlyContinue"
                }
                Invoke-WebRequest @params
            }
            catch {
                throw $_
            }
            Write-Output -InputObject $OutFile
        }
    }
}

function Expand-Dmg ($Path, $PkgFile) {
    if (Test-Path -Path $Path) {
        try {
            $RegEx = "\/Volumes.*"
            $mount = hdiutil attach $Path
        }
        catch {
            throw "Failed to mount dmg: $Path"
        }

        try {
            # Copy the installer to the scratch directory, removing spaces from the file name
            $VolPath = [RegEx]::Match($mount, $RegEx).Captures.Groups[0].Value
            $Package = Get-ChildItem -Path $VolPath -Filter $PkgFile | Select-Object -First 1
            $NewPackage = Join-Path -Path $(Split-Path -Path $Path -Parent) -ChildPath $((Split-Path -Path $Package -Leaf) -replace " ", "")
            Copy-Item -Path $Package.FullName -Destination $NewPackage
        }
        catch {
            throw "Failed extract Pkg from Dmg. $($_.Exception.Message)"
        }
        finally {
            # Unmount the Dmg
            hdiutil detach $VolPath | Out-Null
            Write-Output -InputObject $NewPackage
        }
    }
    else {
        throw "Cannot find path: $Path"
    }
}

function Get-1Password7 {
    try {
        $params = @{
            Uri             = "https://app-updates.agilebits.com/check/1/20.3.0/OPM7/en/70700010"
            UseBasicParsing = $true
            ErrorAction     = "SilentlyContinue"
        }
        $response = Invoke-RestMethod @params
    }
    catch {
        throw $_
    }
    $url = ($response.sources | Where-Object { $_.name -eq "AgileBits" }).url
    $PSObject = [PSCustomObject]@{
        Version = $response.version
        URI     = $($url -replace "zip$", "pkg")
    }
    Write-Output -Input $PSObject
}

function Get-AdobeReader {
    try {
        $params = @{
            Uri             = "https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/reader/current_version.txt"
            UseBasicParsing = $true
            ErrorAction     = "SilentlyContinue"
        }
        $response = Invoke-RestMethod @params
    }
    catch {
        throw $_
    }
    $Version = $response -replace "\.", ""
    $PSObject = [PSCustomObject]@{
        Version = $Version
        URI     = "https://ardownload2.adobe.com/pub/adobe/reader/mac/AcrobatDC/$Version/AcroRdrDC_$($Version)_MUI.dmg"
    }
    Write-Output -Input $PSObject
}

function Get-CitrixWorkspaceApp {
    try {
        $params = @{
            Uri             = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod/catalog_macos.xml"
            UseBasicParsing = $true
            ErrorAction     = "SilentlyContinue"
        }
        $response = Invoke-RestMethod @params
    }
    catch {
        throw $_
    }
    $PSObject = [PSCustomObject]@{
        Version = ($response.Catalog.Installers | Where-Object { $_.name -eq "Receiver" }).Installer.Version
        URI     = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod$(($response.Catalog.Installers | Where-Object { $_.name -eq "Receiver" }).Installer.DownloadURL)"
    }
    Write-Output -Input $PSObject
}

function Get-MicrosoftTeams {
    try {
        $params = @{
            Uri             = "https://teams.microsoft.com/package/desktopclient/update/1.3.00.30874/osx/x64?ring=general&isDaemonUpdater=true"
            UseBasicParsing = $true
            ErrorAction     = "SilentlyContinue"
        }
        $response = Invoke-RestMethod @params
    }
    catch {
        throw $_
    }
    $PSObject = [PSCustomObject]@{
        Version = [RegEx]::Match($response.url, "(\d+(\.\d+){1,4}).*").Captures.Groups[1].Value
        URI     = $response.url
    }
    Write-Output -Input $PSObject
}

function Get-Zoom {
    $Urls = @("https://zoom.us/client/latest/zoomusInstallerFull.pkg", "https://zoom.us/client/latest/zoomusInstallerFull.pkg?archType=arm64")
    foreach ($Url in $Urls) {
        $Uri = Resolve-SystemNetWebRequest -Uri $Url
        $PSObject = [PSCustomObject]@{
            Version = [RegEx]::Match($Uri, "(\d+(\.\d+){1,4}).*").Captures.Groups[1].Value
            URI     = $Uri
        }
        Write-Output -Input $PSObject
    }
}
#endregion

Save-File -Path $Path -Object $(Get-1Password7)
Save-File -Path $Path -Object $(Get-CitrixWorkspaceApp)
Save-File -Path $Path -Object $(Get-MicrosoftTeams)
Save-File -Path $Path -Object $(Get-Zoom)
$Dmg = Save-File -Path $Path -Object $(Get-AdobeReader)
Expand-Dmg -Path $Dmg -PkgFile "AcroRdr*.pkg"
