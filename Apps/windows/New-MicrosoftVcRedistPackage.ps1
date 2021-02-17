#Requires -Modules VcRedist, IntuneWin32App, PSIntuneAuth, AzureAD
<#
    .SYNOPSIS
        Packages the latest Microsoft Visual C++ Redistributables for Intune deployment.
        Uploads the mew package into the target Intune tenant.

    .NOTES
        For details on IntuneWin32App go here: https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md
        For details on VcRedist go here: https://docs.stealthpuppy.com/docs/vcredist/
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "C:\Temp\VcRedist",

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com",

    [Parameter(Mandatory = $False)]
    [ValidateSet("2010", "2012", "2013", "2019")]
    [System.String[]] $VcRelease = @("2010", "2012", "2013", "2019"),

    [Parameter(Mandatory = $False)]
    [ValidateSet("x86", "x64")]
    [System.String[]] $VcArchitecture = @("x86", "x64")
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


# Download VcRedist installer and updates with VcRedist
Write-Information -MessageData "Getting VcRedist details."
$VcRedists = Get-VcList -Release $VcRelease -Architecture $VcArchitecture
If ($VcRedists) {
    
    # Create the package folder
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    Write-Information -MessageData "Check package path: $PackagePath."
    If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    #region Download files and setup the package
    Save-VcRedist -Path $PackagePath -VcList $VcRedists
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

    # Common variables for the package
    $Publisher = "Microsoft"
    $PrivacyUrl = "https://go.microsoft.com/fwlink/?LinkId=521839"

    ForEach ($VcRedist in $VcRedists) {

        # Variables for the package
        $DisplayName = "$Publisher Visual C++ Redistributable $($VcRedist.Release) $($VcRedist.Architecture) $($VcRedist.Version)"
        $Description = "$Publisher $($VcRedist.Name) $($VcRedist.Architecture) $($VcRedist.Version)."
        $Description += "`n`nSee this document for more info: [The latest supported Visual C++ downloads](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads)."
        $exe = Split-Path -Path $VcRedist.Download -Leaf
        $InstallCommandLine = ".\$exe $($VcRedist.SilentInstall)"
        $UninstallCommandLine = "msiexec.exe /X $($VcRedist.ProductCode) /QN-"

        # Build a path to the VcRedist installer
        $VcRedistPath = [System.IO.Path]::Combine($PackagePath, $VcRedist.Release, $VcRedist.Architecture, $VcRedist.ShortName)
        Write-Information -MessageData "Check input path: $VcRedistPath."
        
        # Build a path to the VcRedist package output
        $PackageOutput = [System.IO.Path]::Combine($Path, "Output", $VcRedist.Release, $VcRedist.Architecture, $VcRedist.ShortName)
        Write-Information -MessageData "Check output path: $PackageOutput."
        If (!(Test-Path $PackageOutput)) { New-Item -Path $PackageOutput -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        try {
            # Create the package
            Write-Information -MessageData "Running: $wrapperBin -c $VcRedistPath -s $exe -o $PackageOutput -q"
            Start-Process -FilePath $wrapperBin -ArgumentList "-c $VcRedistPath -s $exe -o $PackageOutput -q" -Wait -NoNewWindow
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to convert to an Intunewin package with: $($_.Exception.Message)"
            Break
        }
        try {
            Write-Information -MessageData "Getting packages from: $PackageOutput."
            $IntuneWinFile = Get-ChildItem -Path $PackageOutput -Filter "*.intunewin" -ErrorAction "SilentlyContinue"
        }
        catch {
            Write-Warning -Message "Failed to find an Intunewin package in $PackageOutput with: $($_.Exception.Message)"
            Break
        }
        Write-Information -MessageData "Found package: $($IntuneWinFile.FullName)."
        #endregion

        #region Upload intunewin file and create the Intune app
        # Convert image file to icon
        $ImageSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Microsoft-VisualStudio.png"
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
        $params = @{
            ProductCode            = $VcRedist.ProductCode
            ProductVersionOperator = "greaterThanOrEqual"
            ProductVersion         = $VcRedist.Version
        }
        $DetectionRule = New-IntuneWin32AppDetectionRuleMSI @params
    
        # Create custom requirement rule
        Switch ($VcRedist.Architecture) {
            "x86" {
                $Architecture = "All"
            }
            "x64" {
                $Architecture = "x64"
            }
        }
        $params = @{
            Architecture                    = $Architecture
            MinimumSupportedOperatingSystem = "1607"
        }
        $RequirementRule = New-IntuneWin32AppRequirementRule @params

        # Add new EXE Win32 app; Requires a connection via Connect-MSIntuneGraph first
        try {
            $params = @{
                FilePath                 = $IntuneWinFile.FullName
                DisplayName              = $DisplayName
                Description              = $Description
                Publisher                = $Publisher
                InformationURL           = $VcRedist.URL
                PrivacyURL               = $PrivacyUrl
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
            <#
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
            #>
        }
    }
    #endregion
}
Else {
    Write-Information -MessageData "Failed to retrieve packages from VcRedist."
}
