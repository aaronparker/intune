#Requires -Modules Evergreen, IntuneWin32App, PSIntuneAuth, AzureAD
<#
    .SYNOPSIS
        Packages the latest Adobe Acrobat Reader DC (US English) for Intune deployment.
        Uploads the mew package into the target Intune tenant.

    .NOTES
        For details on IntuneWin32App go here: https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md
        For details on Evergreen go here: https://stealthpuppy.com/Evergreen
    
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


# Check if token has expired and if, request a new
Write-Information -MessageData "Checking for existing authentication token."
If ($Null -ne $Global:AuthToken) {
    $UTCDateTime = (Get-Date).ToUniversalTime()
    $TokenExpireMins = ($Global:AuthToken.ExpiresOn.datetime - $UTCDateTime).Minutes
    Write-Warning -Message "Current authentication token expires in (minutes): $($TokenExpireMins)"

    If ($TokenExpireMins -le 0) {
        Write-Information -MessageData "Existing token found but has expired, requesting a new token."
        $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName
    }
    Else {
        Write-Information -MessageData "Existing authentication token has not expired, will not request a new token."
    }        
}
Else {
    Write-Information -MessageData "Authentication token does not exist, requesting a new token."
    $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -PromptBehavior "Auto"
}


# Download Reader installer and updates with Evergreen
Write-Information -MessageData "Getting Adobe Acrobat Reader DC version via Evergreen."
$Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq "English" -or $_.Language -eq "Neutral" }
If ($Reader) {
    
    # Create the package folder
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    Write-Information -MessageData "Check path: $PackagePath."
    If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }


    #region Download files and setup the package
    # Grab the most recent installer and update objects in case there happens to be more than one
    $Installer = ($Reader | Where-Object { $_.Type -eq "Installer" | Sort-Object -Property "Version" -Descending })[-1]
    $Updater = ($Reader | Where-Object { $_.Type -eq "Updater" | Sort-Object -Property "Version" -Descending })[-1]
        
    # Download the Adobe Reader installer
    ForEach ($File in $Installer) {
        $OutFile = Join-Path -Path $PackagePath -ChildPath (Split-Path -Path $File.Uri -Leaf)
        Write-Information -MessageData "Installer target: $OutFile."
        If (Test-Path -Path $OutFile) {
            Write-Information -MessageData "File exists: $OutFile."
        }
        Else {
            Write-Information -MessageData "Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Information -MessageData "Downloaded: $OutFile." }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to download Adobe Reader installer with: $($_.Exception.Message)"
                Break
            }
        }
    }

    # Download the updater if the updater version is greater than the installer
    If ($Updater.Version -gt $Installer.Version) {
        ForEach ($File in $Updater) {
            $OutFile = Join-Path -Path $PackagePath -ChildPath (Split-Path -Path $File.Uri -Leaf)
            Write-Information -MessageData "Patch file target: $OutFile."
            If (Test-Path -Path $OutFile) {
                Write-Information -MessageData "File exists: $OutFile."
            }
            Else {
                Write-Information -MessageData "Downloading to: $OutFile."
                try {
                    Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                    If (Test-Path -Path $OutFile) { Write-Information -MessageData "Downloaded: $OutFile." }
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to download Adobe Reader update patch with: $($_.Exception.Message)"
                    Break
                }
            }
        }
    }
    Else {
        Write-Information -MessageData "Installer already up to date, skipping patch file."
    }
    #endregion


    #region Get resource strings and write out a script that will install Reader
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"
    
    # Build the installation script
    Remove-Variable -Name "ScriptContent" -ErrorAction "SilentlyContinue"
    [System.String] $ScriptContent
    $ScriptContent += "# $($res.Name)"
    $ScriptContent += "`n"
    $ScriptContent += "`$InstallFolder = Resolve-Path -Path `$PWD"
    $ScriptContent += "`n"
    $Installers = Get-ChildItem -Path $PackagePath -Filter "*.exe"
    ForEach ($exe in $Installers) {
        $ScriptContent += "`$r = Start-Process -FilePath `"`$InstallFolder\$exe`" -ArgumentList `"$($res.Install.Physical.Arguments)`" -Wait -PassThru"
        $ScriptContent += "`n"
    }
    $Updates = Get-ChildItem -Path $PackagePath -Filter "*.msp"
    ForEach ($msp in $Updates) {
        $ScriptContent += "Start-Process -FilePath `"$env:SystemRoot\System32\msiexec.exe`" -ArgumentList `"/update $msp /quiet /qn-`" -Wait"
        $ScriptContent += "`n"
    }
    $ScriptContent += "Return `$r.ExitCode"
    $ScriptContent += "`n"
    try {
        $ScriptContent | Out-File -FilePath "$PackagePath\$ScriptName" -Encoding "Utf8" -NoNewline -Force
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to write install script $PackagePath\$ScriptName with: $($_.Exception.Message)"
        Break
    }
    #endregion


    #region Package the app
    # Download the Intune Win32 wrapper
    $wrapperUrl = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"
    $wrapperBin = Join-Path -Path $Path -ChildPath (Split-Path -Path $wrapperUrl -Leaf)
    try {
        Invoke-WebRequest -Uri $wrapperUrl -OutFile $wrapperBin -UseBasicParsing
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to Microsoft Win32 Content Prep Tool with: $($_.Exception.Message)"
        Break
    }

    # Create the package
    try {
        $PackageOutput = Join-Path -Path $Path -ChildPath "Output"
        Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $exe -o $PackageOutput -q" -Wait -NoNewWindow
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to convert to an Intunewin package with: $($_.Exception.Message)"
        Break
    }
    try {
        $IntuneWinFile = Get-ChildItem -Path $PackageOutput -Filter "*.intunewin" -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Warning -Message "Failed to find an Intunewin package in $PackageOutput with: $($_.Exception.Message)"
        Break
    }
    Write-Information -MessageData "Found package: $($IntuneWinFile.FullName)."
    #endregion


    #region Upload intunewin file and create the Intune app
    # Variables for the package
    $Description = "The leading PDF viewer to print, sign, and annotate PDFs"
    $ProductCode = "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"
    $Publisher = "Adobe"
    $DisplayName = $res.Name + " " + $Installer.Version
    #$InstallCommandLine = "$($AdobeReaderSetup.FileName) /sAll /rs /rps /l"
    $InstallCommandLine = "C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File .\Install-Reader.ps1"
    $UninstallCommandLine = "msiexec.exe /X $ProductCode /QN-"

    # Convert image file to icon
    $ImageSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Adobe-AcrobatReader.png"
    $ImageFile = (Join-Path -Path $Path -ChildPath (Split-Path -Path $ImageSource -Leaf))
    try {
        Invoke-WebRequest -Uri $ImageSource -OutFile $ImageFile -UseBasicParsing
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to download: $ImageSource with: $($_.Exception.Message)"
        Break
    }
    If (Test-Path -Path $ImageFile) {
        $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile
    }
    Else {
        Write-Warning -Message "Cannot find the icon file."
        Break
    }

    # Create detection rule using the en-US MSI product code (1033 in the GUID below correlates to the lcid)
    If ($ProductCode -and $Installer.Version) {
        $params = @{
            ProductCode            = $ProductCode
            ProductVersionOperator = "greaterThanOrEqual"
            ProductVersion         = $Installer.Version
        }
        $DetectionRule = New-IntuneWin32AppDetectionRuleMSI @params
    }
    Else {
        Write-Warning -Message "Cannot create the detection rule - check ProductCode and version number."
        Write-Information -MessageData "ProductCode: $ProductCode."
        Write-Information -MessageData "Version: $($Installer.Version)."
        Break
    }
    
    # Create custom requirement rule
    $params = @{
        Architecture                    = "All"
        MinimumSupportedOperatingSystem = "1607"
    }
    $RequirementRule = New-IntuneWin32AppRequirementRule @params

    # Add new EXE Win32 app
    # Requires a connection via Connect-MSIntuneGraph first
    try {
        $params = @{
            FilePath                 = $IntuneWinFile.FullName
            DisplayName              = $DisplayName
            Description              = $Description
            Publisher                = $Publisher
            InformationURL           = "https://helpx.adobe.com/au/reader/faq.html"
            PrivacyURL               = "https://www.adobe.com/au/privacy/policy.html"
            CompanyPortalFeaturedApp = $false
            InstallExperience        = "system"
            RestartBehavior          = "suppress"
            DetectionRule            = $DetectionRule
            RequirementRule          = $RequirementRule
            InstallCommandLine       = $InstallCommandLine
            UninstallCommandLine     = $UninstallCommandLine
            Icon                     = $Icon
            Verbose                  = $true
        }
        $App = Add-IntuneWin32App @params
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to create application: $DisplayName with: $($_.Exception.Message)"
        Break
    }

    # Create an available assignment for all users
    If ($Null -ne $App) {
        try {
            $params = @{
                Id                           = $App.Id
                Intent                       = "available"
                Notification                 = "showAll"
                DeliveryOptimizationPriority = "foreground"
                #AvailableTime                = ""
                #DeadlineTime                 = ""
                #UseLocalTime                 = $true
                #EnableRestartGracePeriod     = $true
                #RestartGracePeriod           = 360
                #RestartCountDownDisplay      = 20
                #RestartNotificationSnooze    = 60
                Verbose                      = $true
            }
            Add-IntuneWin32AppAssignmentAllUsers @params
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to add assignment to $($App.displayName) with: $($_.Exception.Message)"
            Break
        }
    }
    #endregion
}
Else {
    Write-Information -MessageData "Failed to retrieve Adobe Reader from Evergreen."
}
