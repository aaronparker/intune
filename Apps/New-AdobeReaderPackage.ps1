#Requires -Module Evergreen
<#
    .SYNOPSIS
        Packages Adobe Reader for Intune deployment.

    .NOTES
        Use the following when importing the package into Intune:
        
        Install: C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy RemoteSigned -WindowStyle Hidden -NonInteractive -File .\Install-Reader.ps1
        Uninstall: MsiExec.exe /X "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}" /QB-
        MSI detection: {AC76BA86-7AD7-1033-7B44-AC0F074E4100}
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "C:\Temp\Reader",

    [Parameter(Mandatory = $False)]
    [System.String] $ScriptName = "Install-Reader.ps1"
)

# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

# Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
# Download Reader installer and update
Write-Host "Downloading Reader"
$Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }

If ($Reader) {
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        
    # Download Adobe Reader
    ForEach ($File in $Reader) {
        $OutFile = Join-Path -Path $PackagePath -ChildPath (Split-Path -Path $File.Uri -Leaf)
        If (Test-Path -Path $OutFile) {
            Write-Host "$OutFile exists."
        }
        Else {
            Write-Host "Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Host "Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader."
                Break
            }
        }
    }

    # Get resource strings and write out a script that will install Reader
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"
    "# $($res.Name)" | Set-Content -Path "$PackagePath\$ScriptName" -Force

    # Build the installation script
    $Installers = Get-ChildItem -Path $PackagePath -Filter "*.exe"
    ForEach ($exe in $Installers) {
        "Start-Process -FilePath $exe -ArgumentList '$($res.Install.Physical.Arguments)' -Wait" | Add-Content -Path "$PackagePath\$ScriptName"
    }
    $Updates = Get-ChildItem -Path $PackagePath -Filter "*.msp"
    ForEach ($msp in $Updates) {
        "Start-Process -FilePath '$env:SystemRoot\System32\msiexec.exe' -ArgumentList '/update $msp /quiet /qn' -Wait" | Add-Content -Path "$PackagePath\$ScriptName"
    }

    # Download the Intune Win32 wrapper
    $wrapperUrl = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"
    $wrapperBin = Join-Path -Path $Path -ChildPath (Split-Path -Path $wrapperUrl -Leaf)
    try {
        Invoke-WebRequest -Uri $wrapperUrl -OutFile $wrapperBin -UseBasicParsing
    }
    catch {
        Throw "Failed to Microsoft Win32 Content Prep Tool."
        Break
    }

    # Create the package
    $PackageOutput = Join-Path -Path $Path -ChildPath "Output"
    Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $ScriptName -o $PackageOutput -q" -Wait -NoNewWindow
}
Else {
    Write-Host "Failed to retreive Adobe Reader"
}
