#Requires -Modules VcRedist, IntuneWin32App, PSIntuneAuth, AzureAD
<#
    .SYNOPSIS
        Packages the latest Microsoft Visual C++ Redistributables for Intune deployment.
        Uploads the mew package into the target Intune tenant.
        Requires a connection via Connect-MSIntuneGraph first.

    .NOTES
        For details on IntuneWin32App go here: https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md
        For details on VcRedist go here: https://docs.stealthpuppy.com/docs/vcredist/
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "C:\Temp\VcRedist",

    [Parameter(Mandatory = $False)]
    [ValidateSet("2010", "2012", "2013", "2019")]
    [System.String[]] $VcRelease = @("2010", "2012", "2013", "2019"),

    [Parameter(Mandatory = $False)]
    [ValidateSet("x86", "x64")]
    [System.String[]] $VcArchitecture = @("x86", "x64"),

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com",

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Upload
)

#region Check if token has expired and if, request a new
Write-Information -MessageData "Checking for existing authentication token."
If ($Null -ne $Global:AuthToken) {
    $UtcDateTime = (Get-Date).ToUniversalTime()
    $TokenExpireMins = ($Global:AuthToken.ExpiresOn.datetime - $UtcDateTime).Minutes
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
#endregion


# Variables
Write-Information -MessageData "Getting VcRedist details."
$ProgressPreference = "SilentlyContinue"
$InformationPreference = "Continue"
Write-Information -MessageData "Getting VcRedist details."
$VcRedists = Get-VcList -Release $VcRelease -Architecture $VcArchitecture
$IconSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Microsoft-VisualStudio.png"
$Win32Wrapper = "https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe"
$Publisher = "Microsoft"
$PrivacyUrl = "https://go.microsoft.com/fwlink/?LinkId=521839"
#endregion


# Download VcRedist installer and updates with VcRedist
If ($VcRedists) {
    
    #region Download files and setup the package
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    Write-Information -MessageData "Check package path: $PackagePath."
    If (!(Test-Path -Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
    Save-VcRedist -Path $PackagePath -VcList $VcRedists
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


    ForEach ($VcRedist in $VcRedists) {

        # Build a path to the VcRedist installer
        $VcRedistPath = [System.IO.Path]::Combine($PackagePath, $VcRedist.Release, $VcRedist.Architecture, $VcRedist.ShortName)
        Write-Information -MessageData "Check input path: $VcRedistPath."
        
        # Build a path to the VcRedist package output
        $PackageOutput = [System.IO.Path]::Combine($Path, "Output", $VcRedist.Release, $VcRedist.Architecture, $VcRedist.ShortName)
        Write-Information -MessageData "Check output path: $PackageOutput."
        If (!(Test-Path $PackageOutput)) { New-Item -Path $PackageOutput -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        try {
            # Create the package
            $Executable = Split-Path -Path $VcRedist.Download -Leaf
            Write-Information -MessageData "Running: $wrapperBin -c $VcRedistPath -s $Executable -o $PackageOutput -q"
            Start-Process -FilePath $wrapperBin -ArgumentList "-c $VcRedistPath -s $Executable -o $PackageOutput -q" -Wait -NoNewWindow
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


        #region Convert image file to icon
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
        #endregion


        #region Create detection rule using Registry detection
        Switch ($VcRedist.Architecture) {
            "x86" {
                $KeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            }
            "x64" {
                $KeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            }
        }
        $params = @{
            Existence            = $true
            KeyPath              = "$KeyPath\$($VcRedist.ProductCode)"
            #ValueName            = ""
            Check32BitOn64System = $false
            DetectionType        = "exists"
        }
        $DetectionRule = New-IntuneWin32AppDetectionRuleRegistry @params
        #endregion
    

        #region Create custom requirement rule
        Switch ($VcRedist.Architecture) {
            "x86" {
                $PackageArchitecture = "All"
            }
            "x64" {
                $PackageArchitecture = "x64"
            }
        }
        $params = @{
            Architecture                    = $PackageArchitecture
            MinimumSupportedOperatingSystem = "1607"
        }
        $RequirementRule = New-IntuneWin32AppRequirementRule @params
        #endregion


        #region Add new EXE Win32 app
        If ($PSBoundParameters.Keys.Contains("Upload")) {

            #region Variables for the package
            $DisplayName = "$Publisher Visual C++ Redistributable $($VcRedist.Release) $($VcRedist.Architecture) $($VcRedist.Version)"
            $Description = "$Publisher $($VcRedist.Name) $($VcRedist.Architecture) $($VcRedist.Version)."
            $Description += "`n`nSee this document for more info: [The latest supported Visual C++ downloads](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads)."
            $InstallCommandLine = ".\$Executable $($VcRedist.SilentInstall)"
            $UninstallCommandLine = "msiexec.exe /X $($VcRedist.ProductCode) /QN-"
            #endregion

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

            # Create an available assignment for all devices
            If ($Null -ne $App) {
                try {
                    $params = @{
                        Id                           = $App.Id
                        Intent                       = "required"
                        Notification                 = "hideAll"
                        DeliveryOptimizationPriority = "foreground"
                        Verbose                      = $true
                    }
                    Add-IntuneWin32AppAssignmentAllDevices @params
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
}
Else {
    Write-Information -MessageData "Failed to retrieve packages from VcRedist."
}
