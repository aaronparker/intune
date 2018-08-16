# Requires -Version 3
<#
.SYNOPSIS
    Downloads and installs Citrix Workspace (Win32/Desktop version) for full functionality.
    Allows for Workspace installation via a PowerShell script to Windows 10 with Microsoft Intune.
    Provides basic error checking and outputs to a log file; Add -Verbose for running manually.

.NOTES
    Name: Install-CitrixWorkspace.ps1
    Author: Aaron Parker
    Site: https://stealthpuppy.com
    Twitter: @stealthpuppy
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
Param (
    [Parameter()] $LogFile = "$env:ProgramData\stealthpuppy\Logs\$($MyInvocation.MyCommand.Name).log",
    [Parameter()] $Url = "https://downloadplugins.citrix.com/Windows/CitrixWorkspaceApp.exe",
    [Parameter()] $UrlHdx = "https://downloads.citrix.com/12105/HDX_RealTime_Media_Engine_2.5_for_Windows.msi",
    [Parameter()] $Target = "$env:SystemRoot\Temp\CitrixWorkspace.exe",
    [Parameter()] $BaselineVersion = [System.Version]"18.8.0.19031",
    [Parameter()] $TargetWeb = "$env:SystemRoot\Temp\CitrixWorkspaceWeb.exe",
    [Parameter()] $Rename = $True,
    [Parameter()] $Arguments = '/AutoUpdateCheck=auto /AutoUpdateStream=Current /DeferUpdateCount=5 /AURolloutPriority=Medium /NoReboot /Silent EnableCEIP=False',
    [Parameter()] $VerbosePreference = "Continue"
)
Start-Transcript -Path $LogFile -Append

# Determine whether Workspace is already installed
Write-Verbose -Message "Querying for installed Workspace version."
$Workspace = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Workspace Inside*" }

# If Workspace is not installed, download and install; or installed Workspace less than current proceed with install
If (!($Workspace) -or ($Workspace.Version -lt $BaselineVersion)) {
    
    # Win32 Workspace and Workspace for Store can't coexist. Remove Store version if installed
    # https://docs.citrix.com/en-us/Workspace/windows-store/current-release/install.html
    Write-Verbose -Message "Querying for Workspace for Store."
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "D50536CD.CitrixWorkspace" } | Remove-AppxPackage -AllUsers -ErrorAction Continue -ErrorVariable $ErrorRemoveAppx -Verbose

    # Install the .NET Framework 3.5. This will download the .NET Framework from the Internet
    # Citrix Workspace system requirements: https://docs.citrix.com/en-us/Workspace/windows/current-release/system-requirements.html
    Write-Verbose -Message "Querying for required .NET Framework."
    If ((Get-WindowsCapability -Online -Name "NetFx3~~~~").State -ne "Installed") {
        Write-Verbose -Message "Installing .NET Framework 3.5"
        Add-WindowsCapability -Online -Name "NetFx3~~~~" -ErrorAction Continue -ErrorVariable $ErrorAddDotNet -Verbose
    }

    # Delete the installer if it exists, so that we don't have issues downloading
    If (Test-Path $Target) { Write-Verbose -Message "Deleting $Target"; Remove-Item -Path $Target -Force -ErrorAction Continue -Verbose }

    # Download Citrix Workspace locally; This should succeed, because the machine must have Internet access to receive the script from Intune
    # Will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); Likely won't support proxy servers
    Write-Verbose -Message "Downloading Citrix Workspace from $Url"
    Start-BitsTransfer -Source $Url -Destination $Target -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits -Verbose
    
    # If $Rename is True, rename the executable. Renaming to CitrixWorkspaceWeb.exe supresses the Add Account window without having to set /ALLOWADDSTORE=N
    If ($Rename) { Write-Verbose -Message "Renaming $Target to $TargetWeb"; Rename-Item -Path $Target -NewName $TargetWeb; $Target = $TargetWeb }

    # Install Citrix Workspace; wait 3 seconds to ensure finished; remove installer
    If (Test-Path $Target) {
        Write-Verbose -Message "Installing Citrix Workspace."
        Start-Process -FilePath $Target -ArgumentList $Arguments -Wait
        Write-Verbose -Message "Sleeping for 3 seconds."; Start-Sleep -Seconds 3
        Write-Verbose -Message "Deleting $Target"; Remove-Item -Path $Target -Force -ErrorAction Continue -Verbose
        Write-Verbose -Message "Querying for installed Workspace version."
        $Workspace = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "Citrix Workspace Inside*" } | Select-Object Name, Version
        Write-Verbose -Message "Installed Citrix Workspace: $($Workspace.Version)."
    }
    Else {
        $ErrorInstall = "Citrix Workspace installer path at $Target not found."
    }

    # Download Citrix HDX RealTime Media Engine locally; This should succeed, because the machine must have Internet access to receive the script from Intune
    # Will download regardless of network cost state (i.e. if network is marked as roaming, it will still download); Likely won't support proxy servers
    Write-Verbose -Message "Downloading Citrix HDX RealTime Media Engine from $UrlHdx"
    Start-BitsTransfer -Source $UrlHdx -Destination $Target -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits -Verbose

    # Intune shows basic deployment status in the Overview blade of the PowerShell script properties
    @($ErrorRemoveAppx, $ErrorAddDotNet, $ErrorBits, $ErrorInstall) | Write-Output
}
Else {
    Write-Verbose "Skipping Workspace installation. Installed version is $($Workspace.Version)"
}
Stop-Transcript
