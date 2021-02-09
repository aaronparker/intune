#Requires -Modules Evergreen, IntuneWin32App
<#
    .SYNOPSIS
        Packages the latest Adobe Acrobat Reader DC (US English) for Intune deployment.
        Uploads the mew package into the target Intune tenant.

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
    [System.String] $ScriptName = "Install-Reader.ps1",

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com"
)

# Variables
$ProgressPreference = "SilentlyContinue"
$InformationPreference = "Continue"
$Description = "The leading PDF viewer to print, sign, and annotate PDFs"
$ProductCode = "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"


# Download Reader installer and updates with Evergreen
Write-Information -MessageData "Getting Adobe Acrobat Reader DC version via Evergreen."
$Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq "English" -or $_.Language -eq "Neutral" }
If ($Reader) {
    
    # Create the package folder
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    Write-Information -MessageData "Check path: $PackagePath."
    If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Remove EXE and MSP files in the package folder if they exist
    Get-ChildItem -Path "$PackagePath\*" | Remove-Item -Force -Confirm:$False -Verbose


    #region Download files and setup the package
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
    [System.String] $ScriptContent
    $Installers = Get-ChildItem -Path $PackagePath -Filter "*.exe"
    ForEach ($exe in $Installers) {
        $ScriptContent += "`$r = Start-Process -FilePath `"`$InstallFolder\$exe`" -ArgumentList `"$($res.Install.Physical.Arguments)`" -Wait -PassThru"
    }
    $Updates = Get-ChildItem -Path $PackagePath -Filter "*.msp"
    ForEach ($msp in $Updates) {
        $ScriptContent += "Start-Process -FilePath `"$env:SystemRoot\System32\msiexec.exe`" -ArgumentList `"/update $msp /quiet /qn-`" -Wait"
    }
    $ScriptContent += "Return `$r.ExitCode"
    $ScriptContent | Out-File -Path "$PackagePath\$ScriptName" -Encoding "Utf8" -Force
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
    try {
        $PackageOutput = Join-Path -Path $Path -ChildPath "Output"
        Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $exe -o $PackageOutput -q" -Wait -NoNewWindow
    }
    catch {
        Throw "Failed to convert to an Intunewin package."
        Break
    }
    $IntuneWinFile = Get-ChildItem -Path $PackageOutput -Filter "*.intunewin"
    Write-Information -MessageData "Found package: $($IntuneWinFile.FullName)."
    #endregion


    # Create detection rule using the en-US MSI product code (1033 in the GUID below correlates to the lcid)
    $params = @{
        MSI                       = $true
        MSIProductCode            = $ProductCode
        MSIProductVersionOperator = "greaterThanOrEqual"
        MSIProductVersion         = $Installer.Version
    }
    $DetectionRule = New-IntuneWin32AppDetectionRule @params

    # Create custom requirement rule
    $params = @{
        Architecture                    = "All"
        MinimumSupportedOperatingSystem = "1607"
    }
    $RequirementRule = New-IntuneWin32AppRequirementRule @params


    # Convert image file to icon
    $ImageSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Adobe-AcrobatReader.png"
    $ImageFile = (Join-Path -Path $Path -ChildPath (Split-Path -Path $ImageSource -Leaf))
    try {
        Invoke-WebRequest -Uri $ImageSource -OutFile $ImageFile -UseBasicParsing
    }
    catch {
        Throw "Failed to download: $ImageSource."
        Break
    }
    If (Test-Path -Path $ImageFile) {
        $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile
    }

    # Add new EXE Win32 app
    $DisplayName = "Adobe Reader DC" + " " + $Installer.Version
    $InstallCommandLine = "$($AdobeReaderSetup.FileName) /sAll /rs /rps /l"
    $UninstallCommandLine = "msiexec.exe /X $ProductCode /QN-"
    $params = @{
        TenantName           = $TenantName
        FilePath             = $IntuneWinFile.FullName
        DisplayName          = $DisplayName
        Description          = $Description
        Publisher            = $Publisher
        InstallExperience    = "system"
        RestartBehavior      = "suppress"
        DetectionRule        = $DetectionRule
        RequirementRule      = $RequirementRule
        InstallCommandLine   = $InstallCommandLine
        UninstallCommandLine = $UninstallCommandLine
        Icon                 = $Icon
        Verbose              = $true
    }
    Add-IntuneWin32App @params

    # Create an available assignment for all users
    $params = @{
        TenantName  = $TenantName
        DisplayName = $DisplayName
        Target      = "AllUsers"
        Intent      = "available"
        Verbose     = $true
    }
    Add-IntuneWin32AppAssignment @params
}
Else {
    Write-Information -MessageData "Failed to retreive Adobe Reader from Evergreen."
}
