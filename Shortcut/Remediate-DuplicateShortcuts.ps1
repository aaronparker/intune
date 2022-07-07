<#
    .SYNOPSIS
        Removes shortcuts from user's desktop. Use with Proactive Remediations or PowerShell scripts
 
        For example, detects shortcuts with the following names:
        Microsoft Teams (3).lnk
        Microsoft Teams - Copy (2).lnk
        Microsoft Teams - Copy - Copy (2).lnk
        Microsoft Teams - Copy - Copy.lnk
        Microsoft Teams - Copy.lnk
 
    .NOTES
 	    NAME: Remediate-DuplicateShortcuts.ps1
	    VERSION: 1.0
	    AUTHOR: Aaron Parker
	    TWITTER: @stealthpuppy
 
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Output required by Proactive Remediations.")]
Param ()

#region Functions
Function Get-KnownFolderPath {
    <#
        .SYNOPSIS
            Gets a known folder's path using GetFolderPath.
        .PARAMETER KnownFolder
            The known folder whose path to get. Validates set to ensure only known folders are passed.
        .NOTES
            https://stackoverflow.com/questions/16658015/how-can-i-use-powershell-to-call-shgetknownfolderpath
    #>
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AdminTools', 'ApplicationData', 'CDBurning', 'CommonAdminTools', 'CommonApplicationData', 'CommonDesktopDirectory', 'CommonDocuments', 'CommonMusic', `
                'CommonOemLinks', 'CommonPictures', 'CommonProgramFiles', 'CommonProgramFilesX86', 'CommonPrograms', 'CommonStartMenu', 'CommonStartup', 'CommonTemplates', `
                'CommonVideos', 'Cookies', 'Desktop', 'DesktopDirectory', 'Favorites', 'Fonts', 'History', 'InternetCache', 'LocalApplicationData', 'LocalizedResources', 'MyComputer', `
                'MyDocuments', 'MyMusic', 'MyPictures', 'MyVideos', 'NetworkShortcuts', 'Personal', 'PrinterShortcuts', 'ProgramFiles', 'ProgramFilesX86', 'Programs', 'Recent', `
                'Resources', 'SendTo', 'StartMenu', 'Startup', 'System', 'SystemX86', 'Templates', 'UserProfile', 'Windows')]
        [System.String] $KnownFolder
    )
    [Environment]::GetFolderPath($KnownFolder)
}
#endregion

# Get shortcuts from the Public desktop
try {
    $Path = Get-KnownFolderPath -KnownFolder "Desktop"
    $Filter = "(.*Copy.*lnk$)|(.*\(\d\).*lnk$)"
    $Shortcuts = Get-ChildItem -Path $Path | Where-Object { $_.Name -match $Filter }
}
catch {
    Write-Host "Failed when enumerating shortcuts at: $Path. $($_.Exception.Message)"
    Exit 1
}    

try {
    If ($Shortcuts.Count -gt 0) { $Shortcuts | Remove-Item -Force -ErrorAction "SilentlyContinue" }
}
catch {
    Write-Host "Failed when deleting shortcuts at: $Path. $($_.Exception.Message)"
    Exit 1
}

# All settings are good exit cleanly
# Output all shortcuts in a list with line breaks in a single output
ForEach ($Shortcut in $Shortcuts) {
    $Output += "$($Shortcut.FullName)`n"
}
Write-Host "Removed shortcuts:`n$Output"

#region
<#
    Source:
    https://msendpointmgr.com/2020/06/25/endpoint-analytics-proactive-remediations/
#>
Function Display-ToastNotification() {
    $Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    # Load the notification into the required format
    $ToastXML = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXML.LoadXml($Toast.OuterXml)
        
    # Display the toast notification
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
    }
    catch { 
        Write-Output -Message 'Something went wrong when displaying the toast notification' -Level Warn
        Write-Output -Message 'Make sure the script is running as the logged on user' -Level Warn     
    }
}
<# Setting image variables
$LogoImageUri = "https://azurefilesnorway.blob.core.windows.net/brandingpictures/Notifications/SCConfigMgr_Symbol_512.png"
$HeroImageUri = "https://azurefilesnorway.blob.core.windows.net/brandingpictures/Notifications/MSEndpoingMgrHeroImage.png"
$LogoImage = "$env:TEMP\ToastLogoImage.png"
$HeroImage = "$env:TEMP\ToastHeroImage.png"

#Fetching images from uri
Invoke-WebRequest -Uri $LogoImageUri -OutFile $LogoImage
Invoke-WebRequest -Uri $HeroImageUri -OutFile $HeroImage
#>

#Defining the Toast notification settings
#ToastNotification Settings
$Scenario = 'reminder' # <!-- Possible values are: reminder | short | long -->
        
# Load Toast Notification text
$AttributionText = "stealthpuppy Service Desk"
$HeaderText = "Duplicate shortcuts found"
$TitleText = "Duplicate shortcuts have been removed from your desktop"
$BodyText1 = "These shortcuts were removed:"

ForEach ($Shortcut in $Shortcuts) {
    $BodyText2 += "$($Shortcut.Name)`n"
}
$BodyText2 = $BodyText2.TrimEnd("`n")

# Check for required entries in registry for when using Powershell as application for the toast
# Register the AppID in the registry for use with the Action Center, if required
$RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$App = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

# Creating registry entries if they don't exist
if (-NOT(Test-Path -Path "$RegPath\$App")) {
    New-Item -Path "$RegPath\$App" -Force > $Null
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' > $Null
}

# Make sure the app used with the action center is enabled
if ((Get-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -ErrorAction SilentlyContinue).ShowInActionCenter -ne '1') {
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force > $Null
}


# Formatting the toast notification XML
[xml]$Toast = @"
<toast scenario="$Scenario">
    <visual>
    <binding template="ToastGeneric">
        <text placement="attribution">$AttributionText</text>
        <text>$HeaderText</text>
        <group>
            <subgroup>
                <text hint-style="title" hint-wrap="true" >$TitleText</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style="body" hint-wrap="true" >$BodyText1</text>
            </subgroup>
        </group>
        <group>
            <subgroup>     
                <text hint-style="body" hint-wrap="true" >$BodyText2</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <actions>
        <action activationType="system" arguments="dismiss" content="$DismissButtonContent"/>
    </actions>
</toast>
"@

#Send the notification
Display-ToastNotification
Exit 0
#endregion
