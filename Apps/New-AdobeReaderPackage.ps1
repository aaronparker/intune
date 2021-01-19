#Requires -Module Evergreen
<#
    .SYNOPSIS
        Packages the latest Adobe Acrobat Reader DC (US English) for Intune deployment.

    .NOTES
        Use the following when importing the package into Intune:
        
        Install: C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy RemoteSigned -WindowStyle Hidden -NonInteractive -File .\Install-Reader.ps1
        Uninstall: MsiExec.exe /X "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}" /QN-
        MSI detection: {AC76BA86-7AD7-1033-7B44-AC0F074E4100}

        # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
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
$InformationPreference = "Continue"

# Create the package folder
$PackagePath = Join-Path -Path $Path -ChildPath "Package"
Write-Information -MessageData "Check path: $PackagePath."
If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

# Download Reader installer and updates with Evergreen
Write-Information -MessageData "Getting Adobe Acrobat Reader DC version via Evergreen."
$Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq "English" -or $_.Language -eq "Neutral" }

If ($Reader) {

    #region Download files and setup the package
    # Remove EXE and MSP files in the package folder if they exist
    Get-ChildItem -Path "$PackagePath\*" -Include "*.exe", "*.msp" | Remove-Item -Verbose

    # Grab the most recent installer and update objects in case there happens to be more than one
    $Installer = ($Reader | Where-Object { $_.Type -eq "Installer" | Sort-Object -Property "Version" -Descending })[-1]
    $Updater = ($Reader | Where-Object { $_.Type -eq "Updater" | Sort-Object -Property "Version" -Descending })[-1]
        
    # Download the Adobe Reader installer
    ForEach ($File in $Installer) {
        $OutFile = Join-Path -Path $PackagePath -ChildPath (Split-Path -Path $File.Uri -Leaf)
        Write-Information -MessageData "Downloading to: $OutFile."
        try {
            Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Information -MessageData "Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Adobe Reader installer."
            Break
        }
    }

    # Download the updater if the updater version is greater than the installer
    If ($Updater.Version -gt $Installer.Version) {
        ForEach ($File in $Updater) {
            $OutFile = Join-Path -Path $PackagePath -ChildPath (Split-Path -Path $File.Uri -Leaf)
            Write-Information -MessageData "Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Information -MessageData "Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader update patch."
                Break
            }
        }
    }
    Else {
        Write-Information -MessageData "Installer already up to date, skipping patch file."
    }
    #endregion

    #region Get resource strings and write out a script that will install Reader
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"
    "# $($res.Name)" | Set-Content -Path "$PackagePath\$ScriptName" -Force
    "`$InstallFolder = Resolve-Path -Path `$PWD" | Add-Content -Path "$PackagePath\$ScriptName"

    # Build the installation script
    $Installers = Get-ChildItem -Path $PackagePath -Filter "*.exe"
    ForEach ($exe in $Installers) {
        "`$r = Start-Process -FilePath `"`$InstallFolder\$exe`" -ArgumentList `"$($res.Install.Physical.Arguments)`" -Wait -PassThru" | Add-Content -Path "$PackagePath\$ScriptName"
    }
    $Updates = Get-ChildItem -Path $PackagePath -Filter "*.msp"
    ForEach ($msp in $Updates) {
        "Start-Process -FilePath `"$env:SystemRoot\System32\msiexec.exe`" -ArgumentList `"/update $msp /quiet /qn-`" -Wait" | Add-Content -Path "$PackagePath\$ScriptName"
    }
    "Return `$r.ExitCode" | Add-Content -Path "$PackagePath\$ScriptName"
    #endregion

    #region Package the app
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
    #Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $ScriptName -o $PackageOutput -q" -Wait -NoNewWindow
    Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $exe -o $PackageOutput -q" -Wait -NoNewWindow
    #endregion
}
Else {
    Write-Information -MessageData "Failed to retreive Adobe Reader from Evergreen"
}
