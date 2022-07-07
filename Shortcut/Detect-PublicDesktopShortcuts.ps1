<#
    .SYNOPSIS
        Removes shortcuts from the Public desktop.
        Use with Proactive Remediations or PowerShell scripts

    .NOTES
 	    NAME: Detect-PublicDesktopShortcuts.ps1
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
    $PublicDesktop = Get-KnownFolderPath -KnownFolder "CommonDesktopDirectory"
    $FileTypes = "*.lnk"
    $Shortcuts = Get-ChildItem -Path $PublicDesktop -Filter $FileTypes
}
catch {
    Write-Host "Failed when enumerating shortcuts at: $PublicDesktop. $($_.Exception.Message)"
    Exit 1
}

# If $Shortcuts > 1
# Output all shortcuts in a list with line breaks in a single output
If ($Shortcuts.Count -ge 1) {
    ForEach ($Shortcut in $Shortcuts) {
        $Output += "$($Shortcut.FullName)`n"
    }
    Write-Host "Found shortcuts:`n$Output"
    Exit 1
}

# All settings are good exit cleanly
Write-Host "No shortcuts found at: $PublicDesktop."
Exit 0
