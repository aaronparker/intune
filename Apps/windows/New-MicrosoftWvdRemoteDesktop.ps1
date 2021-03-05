#Requires -Modules Evergreen, IntuneWin32App, PSIntuneAuth, AzureAD
<#
    .SYNOPSIS
        Packages the latest Microsoft Windows Virtual Desktop Remote Desktop for Intune deployment.
        Uploads the mew package into the target Intune tenant.

    .NOTES
        For details on IntuneWin32App go here: https://github.com/MSEndpointMgr/IntuneWin32App/blob/master/README.md
        For details on Evergreen go here: https://stealthpuppy.com/Evergreen
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "C:\Temp\Wvd",

    [Parameter(Mandatory = $False)]
    [System.String] $ScriptName = "Install-RemoteDesktop.ps1",

    [Parameter(Mandatory = $False)]
    [System.String] $TenantName = "stealthpuppylab.onmicrosoft.com",

    [Parameter(Mandatory = $False)]
    [System.Management.Automation.SwitchParameter] $Upload
)

# Variables
$ProgressPreference = "SilentlyContinue"
$InformationPreference = "Continue"


# Check if token has expired and if, request a new
Write-Information -MessageData "Checking for existing authentication token."
If ($Null -ne $Global:AuthToken) {
    $UTCDateTime = (Get-Date).ToUniversalTime()
    $TokenExpireMins = ($Global:AuthToken.ExpiresOn.DateTime - $UTCDateTime).Minutes
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
Write-Information -MessageData "Getting Microsoft Windows Virtual Desktop Remote Desktop version via Evergreen."
$Package = Get-MicrosoftWvdRemoteDesktop | Where-Object { $_.Architecture -eq "x64" }
If ($Package) {
    If ($Package.Count -gt 1) {
        Write-Warning -Message "Found more than 1 installer. Exiting."
        $Package
        Break
    }
    
    # Create the package folder
    $PackagePath = Join-Path -Path $Path -ChildPath "Package"
    Write-Information -MessageData "Check path: $PackagePath."
    If (!(Test-Path $PackagePath)) { New-Item -Path $PackagePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    #region Download files and setup the package        
    # Download the Remote Desktop installer
    $Executable = $Package.FileName
    $OutFile = Join-Path -Path $PackagePath -ChildPath $Executable

    Write-Information -MessageData "Installer target: $OutFile."
    If (Test-Path -Path $OutFile) {
        Write-Information -MessageData "File exists: $OutFile."
    }
    Else {
        Write-Information -MessageData "Downloading to: $OutFile."
        try {
            Invoke-WebRequest -Uri $Package.Uri -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Information -MessageData "Downloaded: $OutFile." }
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to download Remote Desktop installer with: $($_.Exception.Message)"
            Break
        }
    }
    #endregion


    #region Get resource strings and write out a script that will install Remote Desktop
    $res = Export-EvergreenFunctionStrings -AppName "MicrosoftWvdRemoteDesktop"

    Remove-Variable -Name "ScriptContent" -ErrorAction "SilentlyContinue"
    [System.String] $ScriptContent
    $ScriptContent += "# $($res.Name)"
    $ScriptContent += "`n"
    $ScriptContent += "`$r = Start-Process -FilePath `"`$env:SystemRoot\System32\msiexec.exe`" -ArgumentList `"/package `$PWD\`$Executable /quiet /norestart`" -Wait -PassThru"
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
        Start-Process -FilePath $wrapperBin -ArgumentList "-c $PackagePath -s $($Package.Filename) -o $PackageOutput -q" -Wait -NoNewWindow
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
    $Description = "The Microsoft Windows Virtual Desktop Remote Desktop client for Windows Desktop."
    $ProductCode = "{0D305810-09D2-49D9-8AF7-D5459F40BB95}"
    $Publisher = "Microsoft"
    $DisplayName = $res.Name + " " + $Package.Version
    $InstallCommandLine = "C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File .\$ScriptName"
    $UninstallCommandLine = "msiexec.exe /X $ProductCode /QN-"

    # Convert image file to icon
    $ImageSource = "https://raw.githubusercontent.com/Insentra/intune-icons/main/icons/Microsoft-RemoteDesktop-macOS.png"
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
    If ($ProductCode -and $Package.Version) {
        $params = @{
            Version              = $True
            Path                 = "$env:ProgramFiles\Remote Desktop"
            FileOrFolder         = "msrdcw.exe"
            Check32BitOn64System = $True 
            Operator             = "greaterThanOrEqual"
            VersionValue         = $Package.Version
        }
        $DetectionRule = New-IntuneWin32AppDetectionRuleFile @params
    }
    Else {
        Write-Warning -Message "Cannot create the detection rule - check ProductCode and version number."
        Write-Information -MessageData "ProductCode: $ProductCode."
        Write-Information -MessageData "Version: $($Package.Version)."
        Break
    }
    
    # Create custom requirement rule
    $params = @{
        Architecture                    = "x64"
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
                InformationURL           = "https://docs.microsoft.com/en-au/windows-server/remote/remote-desktop-services/clients/windowsdesktop"
                PrivacyURL               = "https://go.microsoft.com/fwlink/?LinkId=521839"
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
    Write-Information -MessageData "Failed to retrieve Remote Desktop from Evergreen."
}
