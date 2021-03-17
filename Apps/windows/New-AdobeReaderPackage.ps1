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
    [ValidateSet("x64", "x86")]
    [System.String[]] $Architecture = "x86",

    [Parameter(Mandatory = $False)]
    [System.String] $Language = "English (UK)",

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com",

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Upload
)

#region Check if token has expired and if, request a new
Write-Host -Foregroundcolor "Cyan" "Checking for existing authentication token."
If ($Null -ne $Global:AuthToken) {
    $UtcDateTime = (Get-Date).ToUniversalTime()
    $TokenExpireMins = ($Global:AuthToken.ExpiresOn.DateTime - $UtcDateTime).Minutes
    Write-Warning -Message "Current authentication token expires in (minutes): $($TokenExpireMins)"

    If ($TokenExpireMins -le 0) {
        Write-Host -Foregroundcolor "Cyan" "Existing token found but has expired, requesting a new token."
        $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName
    }
    Else {
        Write-Host -Foregroundcolor "Cyan" "Existing authentication token has not expired, will not request a new token."
    }        
}
Else {
    Write-Host -Foregroundcolor "Cyan" "Authentication token does not exist, requesting a new token."
    $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -PromptBehavior "Auto"
}
#endregion

# Create a package for each architecture listed in $Architecture
ForEach ($Arch in $Architecture) {

    #region Variables
    Write-Host -Foregroundcolor "Cyan" "Getting Adobe Acrobat Reader DC $Arch version via Evergreen."
    $ProgressPreference = "SilentlyContinue"
    $InformationPreference = "Continue"
    $Package = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq $Language -and $_.Architecture -eq $Arch } | Select-Object -First 1
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"
    $IconSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Adobe-AcrobatReader.png"
    $Win32Wrapper = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"

    # Variables for the package
    $Description = "The leading PDF viewer to print, sign, and annotate PDFs"
    $Publisher = "Adobe"
    $DisplayName = $res.Name + " " + $Arch + " " + $Package.Version
    $Executable = Split-Path -Path $Package.Uri -Leaf
    $InformationURL = "https://acrobat.adobe.com/au/en/acrobat/pdf-reader.html"
    $PrivacyURL = "https://www.adobe.com/privacy.html"
    Switch ($Arch) {
        "x64" {
            $ProductCode = "{AC76BA86-1033-1033-7760-BC15014EA700}"
            $AppPath = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat"
            $AppExecutable = "Acrobat.exe"
        }
        "x86" {
            $ProductCode = "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"
            $AppPath = "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader"
            $AppExecutable = "AcroRd32.exe"
        }
    }
    #$InstallCommandLine = "C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File .\$ScriptName"
    $InstallCommandLine = "$Executable $($res.Install.Physical.Arguments)"
    $UninstallCommandLine = "msiexec.exe /X $ProductCode /QN-"
    #endregion


    # Download installer with Evergreen
    If ($Package) {
 
        # Create the package folder
        $Path = Join-Path -Path $Path -ChildPath $Arch
        $PackagePath = Join-Path -Path $Path -ChildPath "Package"
        Write-Host -Foregroundcolor "Cyan" "Package path: $PackagePath."
        If (!(Test-Path -Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        $PackageOutput = Join-Path -Path $Path -ChildPath "Output"
        Write-Host -Foregroundcolor "Cyan" "Output path: $PackageOutput."

        #region Download files and setup the package
        # Grab the most recent installer and update objects in case there happens to be more than one        
        # Download the Adobe Reader installer
        $OutFile = Join-Path -Path $PackagePath -ChildPath $Executable
        
        Write-Host -Foregroundcolor "Cyan" "Installer target: $OutFile."
        If (Test-Path -Path $OutFile) {
            Write-Host -Foregroundcolor "Cyan" "File exists: $OutFile."
        }
        Else {
            Write-Host -Foregroundcolor "Cyan" "Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $Package.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Host -Foregroundcolor "Cyan" "Downloaded: $OutFile." }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to download Adobe Reader installer with: $($_.Exception.Message)"
                Break
            }
        }
        #endregion


        #region Get resource strings and write out a script that will install Reader
        $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"
    
        # Build the installation script
        Remove-Variable -Name "ScriptContent" -ErrorAction "SilentlyContinue"
        [System.String] $ScriptContent
        $ScriptContent += "# $($res.Name)"
        $ScriptContent += "`n"
        $ScriptContent += "`$r = Start-Process -FilePath `"`$PWD\$Executable`" -ArgumentList `"$($res.Install.Physical.Arguments)`" -Wait -PassThru"
        $ScriptContent += "`n"
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
        $wrapperBin = Join-Path -Path $Path -ChildPath (Split-Path -Path $Win32Wrapper -Leaf)
        try {
            Invoke-WebRequest -Uri $Win32Wrapper -OutFile $wrapperBin -UseBasicParsing
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to Microsoft Win32 Content Prep Tool with: $($_.Exception.Message)"
            Break
        }

        # Create the package
        try {
            Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $Executable -o $PackageOutput -q" -Wait -NoNewWindow
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
        Write-Host -Foregroundcolor "Cyan" "Found package: $($IntuneWinFile.FullName)."
        #endregion


        #region Upload intunewin file and create the Intune app
        # Convert image file to icon
        $ImageFile = (Join-Path -Path $Path -ChildPath (Split-Path -Path $IconSource -Leaf))
        try {
            Invoke-WebRequest -Uri $IconSource -OutFile $ImageFile -UseBasicParsing
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to download: $IconSource with: $($_.Exception.Message)"
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
        If ($ProductCode -and $Package.Version) {
            $params = @{
                ProductCode = $ProductCode
                #ProductVersionOperator = "greaterThanOrEqual"
                #ProductVersion         = $Package.Version
            }
            $DetectionRule1 = New-IntuneWin32AppDetectionRuleMSI @params
        }
        Else {
            Write-Warning -Message "Cannot create the detection rule - check ProductCode and version number."
            Write-Host -Foregroundcolor "Cyan" "ProductCode: $ProductCode."
            Write-Host -Foregroundcolor "Cyan" "Version: $($Package.Version)."
            Break
        }
        If ($AppPath -and $AppExecutable) {
            $params = @{
                Version              = $True
                Path                 = $AppPath
                FileOrFolder         = $AppExecutable
                Check32BitOn64System = $False 
                Operator             = "greaterThanOrEqual"
                VersionValue         = $Package.Version
            }
            $DetectionRule2 = New-IntuneWin32AppDetectionRuleFile @params
        }
        Else {
            Write-Warning -Message "Cannot create the detection rule - check application path and executable."
            Write-Host -Foregroundcolor "Cyan" "Path: $AppPath."
            Write-Host -Foregroundcolor "Cyan" "Exe: $AppExecutable."
            Break
        }
        If ($DetectionRule1 -and $DetectionRule2) {
            $DetectionRule = @($DetectionRule1, $DetectionRule2)
        }
        Else {
            Write-Host -Foregroundcolor "Cyan" "Failed to create the detection rule."
            Break
        }
    
        # Create custom requirement rule
        Switch ($Arch) {
            "x86" { $PackageArchitecture = "All" }
            "x64" { $PackageArchitecture = "x64" }
        }
        $params = @{
            Architecture                    = $PackageArchitecture
            MinimumSupportedOperatingSystem = "1607"
        }
        $RequirementRule = New-IntuneWin32AppRequirementRule @params

        # Add new EXE Win32 app
        # Requires a connection via Connect-MSIntuneGraph first
        If ($PSBoundParameters.Keys.Contains("Upload")) {
            try {
                $params = @{
                    FilePath                 = $IntuneWinFile.FullName
                    DisplayName              = $DisplayName
                    Description              = $Description
                    Publisher                = $Publisher
                    InformationURL           = $InformationURL
                    PrivacyURL               = $PrivacyURL
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
        }
        Else {
            Write-Host -Object "Parameter -Upload not specified. Skipping upload to Intune."
        }
        #endregion
    }
    Else {
        Write-Host -Foregroundcolor "Cyan" "Failed to retrieve Adobe Acrobat Reader DC package via Evergreen."
    }
}
