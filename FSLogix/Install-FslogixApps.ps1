<#
    .SYNOPSIS
        Downloads and installs the FSLogix Apps agent.

    .DESCRIPTION
        Downloads and installs the FSLogix Apps agent. Checks whether the agent is already installed. Installs the agent if it is not installed or not up to date.
        Configures a scheduled task to download the FSLogix App Masking and Java Version Control rulesets from an Azure blog storage container.
        
    .NOTES
        Name: Install-FslogixApps.ps1
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
#Requires -Version 3

# Common Variables
$VerbosePreference = "Continue"
$LogFile = "$env:ProgramData\Scripts\$($MyInvocation.MyCommand.Name).log"
Start-Transcript -Path $LogFile

function Show-Toast {
    <#
    .SYNOPSIS
        Show Windows Toast/ballon for a logged on user

    .PARAMETER ToastTitle
        Parameter Title of the toast

    .PARAMETER ToastText
        Parameter Text for the toast

    .PARAMETER Image
        Parameter Define image either http://, https:// or file://

    .PARAMETER ToastDuration
        Parameter Define how long the toast should stay, long or short, 10 or 4 seconds for alternative popup

    .EXAMPLE
        ShowToast -Image "https://picsum.photos/150/150?image=1060" 
            -ToastTitle "Headline" -ToastText "Text" -ToastDuration short

    .EXAMPLE
        ShowToast -ToastTitle "Headline" -ToastText "Text" -ToastDuration short

    .NOTES
        It will modify the registry value ShowInActionCenter to 1 for PowerShell
        Location HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID
        
        Version: 1.0  First release
        Author: @MattiasFors
        Site: https://deploywindows.com
        GitHub: https://github.com/DeployWindowsCom/DeployWindows-Scripts
    #>
  param(
    [parameter(Mandatory=$true,Position=2)]
    [string] $ToastTitle,
    [parameter(Mandatory=$true,Position=3)]
    [string] $ToastText,
    [parameter(Position=1)]
    [string] $Image = $null,
    [parameter()]
    [ValidateSet('long','short')]
    [string] $ToastDuration = "long"
  )
  # Toast overview: https://msdn.microsoft.com/en-us/library/windows/apps/hh779727.aspx
  # Toasts templates: https://msdn.microsoft.com/en-us/library/windows/apps/hh761494.aspx
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

  # Define Toast template, w/wo image
  $ToastTemplate = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02
  if ($Image.Length -le 0) { $ToastTemplate = [Windows.UI.Notifications.ToastTemplateType]::ToastText02 }

  # Download or define a local image. Toast images must have dimensions =< 1024x1024 size =< 200 KB
  if ($Image -match "http*") {
    [System.Reflection.Assembly]::LoadWithPartialName("System.web") | Out-Null
    $Image = [System.Web.HttpUtility]::UrlEncode($Image)
    $imglocal = "$($env:TEMP)\ToastImage.png"
    Start-BitsTransfer -Destination $imglocal -Source $([System.Web.HttpUtility]::UrlDecode($Image)) -ErrorAction Continue
  } else { $imglocal = $Image }

  # Define the toast template and create variable for XML manipulation
  # Customize the toast title, text, image and duration
  $toastXml = [xml] $([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(`
    $ToastTemplate)).GetXml()
  $toastXml.GetElementsByTagName("text")[0].AppendChild($toastXml.CreateTextNode($ToastTitle)) | Out-Null
  $toastXml.GetElementsByTagName("text")[1].AppendChild($toastXml.CreateTextNode($ToastText)) | Out-Null
  if ($Image.Length -ge 1) { $toastXml.GetElementsByTagName("image")[0].SetAttribute("src", $imglocal) }
  $toastXml.toast.SetAttribute("duration", $ToastDuration)

  # Convert back to WinRT type
  $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml($toastXml.OuterXml);
  $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

  # Get an unique AppId from start, and enable notification in registry
  if ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value.ToString() -eq "S-1-5-18") {
    # Popup alternative when running as system. https://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx
    $wshell = New-Object -ComObject Wscript.Shell
    if ($ToastDuration -eq "long") { $return = $wshell.Popup($ToastText,10,$ToastTitle,0x100) }
    else { $return = $wshell.Popup($ToastText,4,$ToastTitle,0x100) }
  } else {
    $AppID = ((Get-StartApps -Name 'Windows Powershell') | Select -First 1).AppId
    New-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" -Force | Out-Null
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" `
      -Name "ShowInActionCenter" -Type Dword -Value "1" -Force | Out-Null
    # Create and show the toast, dont forget AppId
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID).Show($Toast)
  }
}


# Variables
$Target = "$env:SystemRoot\Temp"
$Arguments = "/install /quiet /norestart ProductKey=TRIAL-G6KID-WKRKO-J96IA-O9SB7"

# Set installer download URL based on processor architecture
Switch ((Get-WmiObject Win32_OperatingSystem).OSArchitecture) {
    "32-bit" { Write-Verbose -Message "32-bit processor"; $Url = "https://stlhppymdrn.blob.core.windows.net/fslogix-agent/x86/FSLogixAppsSetup.exe" }
    "64-bit" { Write-Verbose -Message "64-bit processor"; $Url = "https://stlhppymdrn.blob.core.windows.net/fslogix-agent/x64/FSLogixAppsSetup.exe" }
}

# Download FSLogix Agent installer
$Installer = Split-Path -Path $Url -Leaf
Write-Verbose -Message "Downloading $Url to $Target\$Installer"
Start-BitsTransfer -Source $Url -Destination "$Target\$Installer" -Priority High -TransferPolicy Always -ErrorAction Continue -ErrorVariable $ErrorBits
$ProductVersion = (Get-ItemProperty -Path "$Target\$Installer").VersionInfo.ProductVersion

# Determine whether FSLogix Agent is already installed
Write-Verbose -Message "Querying for installed FSLogix Apps version."
$Agent = Get-WmiObject -Class Win32_Product -ErrorAction Continue | Where-Object { $_.Name -Like "FSLogix Apps" } | Select-Object Name, Version
If ($Agent) { Write-Verbose "Found FSLogix Apps $($Agent.Version)." }

# Install the FSLogix Agent
If (Test-Path "$Target\$Installer") {

    # If installed version less than downloaded version, install the update
    If (!($Agent) -or ($Agent.Version -lt $ProductVersion)) {
        Write-Verbose -Message "Installing the FSLogix Agent $ProductVersion."; 
        Start-Process -FilePath "$Target\$Installer" -ArgumentList $Arguments -Wait
        Write-Verbose -Message "Deleting $Target\$Installer"; Remove-Item -Path "$Target\$Installer" -Force -ErrorAction Continue
        Write-Verbose -Message "Querying for installed FSLogix Agent."
        $Agent = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Like "FSLogix Apps" } | Select-Object Name, Version
        Write-Verbose -Message "Installed FSLogix Agent: $($Agent.Version)."
        Show-Toast -ToastTitle "FSLogix Apps was installed." `
            -ToastText "A new application has been installed that requires a restart. Please save your work and restart your PC as soon as possible." -ToastDuration long;
    } Else {

        # Skip install if agent already installed and up to date
        Write-Verbose "Skipping installation of the FSLogix Agent. Version $($Agent.Version) already installed."
    }
} Else {
    Write-Verbose "Unable to find the FSLogix Apps installer."
    # If we get here, it's possible the script couldn't download the installer
    # Delete script key under HKLM\SOFTWARE\Microsoft\IntuneManagementExtension to get script to re-run
    $KeyParent = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Policies"
    $ScriptName = Split-Path -Path $MyInvocation.MyCommand.Name -Leaf
    $KeyPath = "$KeyParent\$($ScriptName.Split("_")[0])\$($ScriptName.Split("_")[1] -replace ".ps1")"
    If (Test-Path -Path $KeyPath) {
        Write-Verbose "Removing registry key to force script to re-run: $KeyPath"
        Remove-Item -Path $KeyPath -Force
    }
    Stop-Transcript
    Break
}

# Add configure scheduled task here.

Stop-Transcript