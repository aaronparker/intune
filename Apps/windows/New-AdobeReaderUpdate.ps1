#Requires -Modules IntuneWin32App, PSIntuneAuth, AzureAD
#Requires -Modules @{ ModuleName="Evergreen"; ModuleVersion="2104.355" }
<#
    .SYNOPSIS
        Packages the latest Adobe Acrobat Reader DC (US English) for Intune deployment.
        Uploads the mew package into the target Intune tenant.

    .NOTES
        For details on IntuneWin32App go here: https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md
        For details on Evergreen go here: https://stealthpuppy.com/Evergreen
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "C:\Temp\Reader",

    [Parameter(Mandatory = $False)]
    [System.String] $ScriptName = "Install-Reader.ps1",

    [Parameter(Mandatory = $False)]
    [ValidateSet("Neutral", "Multi")]
    [System.String] $Language = "Neutral",

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com",

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Upload
)

#region Check if token has expired and if, request a new
Write-Host -ForegroundColor "Cyan" "Checking for existing authentication token for tenant: $TenantName."
If ($Null -ne $Global:AuthToken) {
    $UtcDateTime = (Get-Date).ToUniversalTime()
    $TokenExpireMins = ($Global:AuthToken.ExpiresOn.DateTime - $UtcDateTime).Minutes
    Write-Warning -Message "Current authentication token expires in (minutes): $($TokenExpireMins)"

    If ($TokenExpireMins -le 0) {
        Write-Host -ForegroundColor "Cyan" "Existing token found but has expired, requesting a new token."
        $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName
    }
    Else {
        Write-Host -ForegroundColor "Cyan" "Existing authentication token has not expired, will not request a new token."
    }        
}
Else {
    Write-Host -ForegroundColor "Cyan" "Authentication token does not exist, requesting a new token."
    $Global:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -PromptBehavior "Auto"
}
#endregion

# Create a package for each language listed in $Language
ForEach ($Lang in $Language) {

    #region Variables
    Write-Host -ForegroundColor "Cyan" "Getting Adobe Acrobat Reader DC updates via Evergreen."
    $ProgressPreference = "SilentlyContinue"
    $InformationPreference = "Continue"
    $IconSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Adobe-AcrobatReader.png"
    $Win32Wrapper = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"

    $Package = Get-EvergreenApp -Name "AdobeAcrobat" | Where-Object { $_.Product -eq "Reader" -and $_.Track -eq "DC" -and $_.Language -eq "Neutral" } | Select-Object -First 1
    $res = Export-EvergreenManifest -Name "AdobeAcrobat"
    
    # Variables for the package
    $Description = "The leading PDF viewer to print, sign, and annotate PDFs"
    $Publisher = "Adobe"
    $DisplayName = $res.Name + " Update " + $Package.Version
    $Executable = Split-Path -Path $Package.Uri -Leaf
    $InformationURL = "https://helpx.adobe.com/au/acrobat/release-note/release-notes-acrobat-reader.html"
    $PrivacyURL = "https://www.adobe.com/privacy.html"

    $ProductCode = "{AC76BA86-1033-1033-7760-BC15014EA700}"
    $AppPath = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat"
    $AppExecutable = "Acrobat.exe"

    $ProductCode = "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"
    $AppPath = "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader"
    $AppExecutable = "AcroRd32.exe"

    $InstallCommandLine = "msiexec.exe /Update .\$Executable /Quiet"
    $UninstallCommandLine = "msiexec.exe /X $ProductCode /QN-"
    #endregion


    # Download installer with Evergreen
    If ($Package) {
 
        # Create the package folder
        $PackagePath = Join-Path -Path $Path -ChildPath "Package"
        Write-Host -ForegroundColor "Cyan" "Package path: $PackagePath."
        If (!(Test-Path -Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        $PackageOutput = Join-Path -Path $Path -ChildPath "Output"
        Write-Host -ForegroundColor "Cyan" "Output path: $PackageOutput."

        #region Download files and setup the package
        # Grab the most recent installer and update objects in case there happens to be more than one        
        # Download the Adobe Reader installer
        $OutFile = Save-EvergreenApp -InputObject $Package -Path $PackagePath
        #endregion
    
        #region Package the app
        # Download the Intune Win32 wrapper
        $wrapperBin = Join-Path -Path $Path -ChildPath (Split-Path -Path $Win32Wrapper -Leaf)
        try {
            Invoke-WebRequest -Uri $Win32Wrapper -OutFile $wrapperBin -UseBasicParsing
        }
        catch [System.Exception] {
            Write-Error -Message "Failed to Microsoft Win32 Content Prep Tool with: $($_.Exception.Message)"
            Break
        }

        # Create the package
        try {
            Write-Host -ForegroundColor "Cyan" "Package path: $(Split-Path -Path $OutFile.Path -Parent)."
            Write-Host -ForegroundColor "Cyan" "Update path:  $($OutFile.Path)."
            $params = @{
                FilePath     = $wrapperBin
                ArgumentList = "-c $(Split-Path -Path $OutFile.Path -Parent) -s $($OutFile.Path) -o $PackageOutput -q"
                Wait         = $True
                PassThru     = $True
                NoNewWindow  = $True
            }
            $process = Start-Process @params
        }
        catch [System.Exception] {
            Write-Error -Message "Failed to convert to an Intunewin package with: $($_.Exception.Message)"
            Break
        }
        try {
            $IntuneWinFile = Get-ChildItem -Path $PackageOutput -Filter "*.intunewin" -ErrorAction "SilentlyContinue"
        }
        catch {
            Write-Error -Message "Failed to find an Intunewin package in $PackageOutput with: $($_.Exception.Message)"
            Break
        }
        Write-Host -ForegroundColor "Cyan" "Found package: $($IntuneWinFile.FullName)."
        #endregion


        #region Upload intunewin file and create the Intune app
        # Convert image file to icon
        $ImageFile = (Join-Path -Path $Path -ChildPath (Split-Path -Path $IconSource -Leaf))
        try {
            Invoke-WebRequest -Uri $IconSource -OutFile $ImageFile -UseBasicParsing
        }
        catch [System.Exception] {
            Write-Error -Message "Failed to download: $IconSource with: $($_.Exception.Message)"
            Break
        }
        If (Test-Path -Path $ImageFile) {
            $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile
        }
        Else {
            Write-Error -Message "Cannot find the icon file."
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
            Write-Host -ForegroundColor "Cyan" "ProductCode: $ProductCode."
            Write-Host -ForegroundColor "Cyan" "Version: $($Package.Version)."
            Write-Error -Message "Cannot create the detection rule - check ProductCode and version number."
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
            Write-Error -Message "Cannot create the detection rule - check application path and executable."
            Write-Host -ForegroundColor "Cyan" "Path: $AppPath."
            Write-Host -ForegroundColor "Cyan" "Exe: $AppExecutable."
            Break
        }
        If ($DetectionRule1 -and $DetectionRule2) {
            $DetectionRule = @($DetectionRule1, $DetectionRule2)
        }
        Else {
            Write-Error -Message "Failed to create the detection rule."
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
                Write-Error -Message "Failed to create application: $DisplayName with: $($_.Exception.Message)"
                Break
            }

            # Create an available assignment for all users
            <#
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
            #>
        }
        Else {
            Write-Warning -Message "Parameter -Upload not specified. Skipping upload to Intune."
        }
        #endregion
    }
    Else {
        Write-Error -Message "Failed to retrieve Adobe Acrobat Reader update package via Evergreen."
    }
}
