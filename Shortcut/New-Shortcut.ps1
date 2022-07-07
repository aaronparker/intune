<#
    .SYNOPSIS
        Create a shortcut to an application.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
[CmdletBinding()]
Param()

Function Get-KnownFolderPath {
    <#
        .SYNOPSIS
            Gets a known folder's path using GetFolderPath.
        .PARAMETER KnownFolder
            The known folder whose path to get. Validates set to ensure only knwwn folders are passed.
        .NOTES
            https://stackoverflow.com/questions/16658015/how-can-i-use-powershell-to-call-shgetknownfolderpath
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AdminTools', 'ApplicationData', 'CDBurning', 'CommonAdminTools', 'CommonApplicationData', `
                'CommonDesktopDirectory', 'CommonDocuments', 'CommonMusic', 'CommonOemLinks', 'CommonPictures', `
                'CommonProgramFiles', 'CommonProgramFilesX86', 'CommonPrograms', 'CommonStartMenu', 'CommonStartup', `
                'CommonTemplates', 'CommonVideos', 'Cookies', 'Desktop', 'DesktopDirectory', 'Favorites', `
                'Fonts', 'History', 'InternetCache', 'LocalApplicationData', 'LocalizedResources', 'MyComputer', `
                'MyDocuments', 'MyMusic', 'MyPictures', 'MyVideos', 'NetworkShortcuts', 'Personal', 'PrinterShortcuts', `
                'ProgramFiles', 'ProgramFilesX86', 'Programs', 'Recent', 'Resources', 'SendTo', `
                'StartMenu', 'Startup', 'System', 'SystemX86', 'Templates', 'UserProfile', 'Windows')]
        [string] $KnownFolder
    )

    $folder = [Environment]::GetFolderPath($KnownFolder)
    Write-Verbose "Location for $KnownFolder is $folder."
    Write-Output $folder
}

Function New-Shortcut {
    [CmdletBinding()]
    Param (
        [ValidateNotNullOrEmpty]
        [string] $Path,

        [ValidateNotNullOrEmpty]
        [string] $Target,

        [string] $Arguments,
        [string] $WorkingDirectory,
        [string] $WindowStyle = 1,
        [string] $Hotkey,
        [string] $Icon,
        [string] $Description
    )
    try {
        Write-Verbose "Creating shortcut $($Path)."
        $shell = New-Object -ComObject ("WScript.Shell")
        $shortCut = $shell.CreateShortcut($Path)
        $shortCut.TargetPath = $Target
        $shortCut.Arguments = $Arguments
        $shortCut.WorkingDirectory = $WorkingDirectory
        $shortCut.WindowStyle = $WindowStyle
        $shortCut.Hotkey = $Hotkey
        $shortCut.IconLocation = $Icon
        $shortCut.Description = $Description
        $shortCut.Save()
    }
    catch {
        Write-Error "Failed to create shortcut with error: $_"
    }
    finally {
        Write-Output $Path
    }
}

# Start log file
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:LocalAppData\IntuneScriptLogs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile

# Create shortcut locations
$shortcuts = @($(Get-KnownFolderPath -KnownFolder Desktop), "$(Get-KnownFolderPath -KnownFolder StartMenu)\Programs")

# Create the shortcuts
ForEach ($shortcut in $shortcuts) {
    If (Test-Path -Path $shortcut) {
        # Create New-Shortcut arguments
        $shortcutArgs = @{
            Path             = "$shortcut\Microsoft Teams.lnk"
            Target           = "$env:LocalAppData\Microsoft\Teams\Update.exe"
            Arguments        = '--processStart "Teams.exe"'
            WorkingDirectory = "$env:LocalAppData\Microsoft\Teams"
            WindowStyle      = 1
            Hotkey           = ""
            Icon             = "$env:LocalAppData\Microsoft\Teams\Update.exe, 0"
            Description      = "Microsoft Teams"
        }

        If (!(Test-Path -Path $($shortcutArgs.Path))) {
            New-Shortcut @shortcutArgs
        }
        Else {
            Write-Verbose "Shortcut $($shortcutArgs.Path) exists."
        }
    }
}

Stop-Transcript
