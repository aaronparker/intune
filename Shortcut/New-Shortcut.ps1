<#
    .SYNOPSIS
        Create a shortcut to an application.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param()

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
        [System.String] $KnownFolder
    )

    $folder = [Environment]::GetFolderPath($KnownFolder)
    Write-Verbose "Location for $KnownFolder is $folder."
    Write-Output $folder
}

Function New-Shortcut {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        [ValidateNotNullOrEmpty]
        [System.String] $Path,

        [ValidateNotNullOrEmpty]
        [System.String] $Target,

        [System.String] $Arguments,
        [System.String] $WorkingDirectory,
        [System.String] $WindowStyle = 1,
        [System.String] $Hotkey,
        [System.String] $Icon,
        [System.String] $Description
    )
    try {
        if ($PSCmdlet.ShouldProcess($Path, ("Creating shortcut '{0}'" -f $Path))) {
            Write-Verbose -Message "Creating shortcut $($Path)."
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
        Write-Output $Path
    }
    catch {
        Write-Error -Message "Failed to create shortcut with error: $_"
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
foreach ($shortcut in $shortcuts) {
    if (Test-Path -Path $shortcut) {
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

        if (!(Test-Path -Path $($shortcutArgs.Path))) {
            New-Shortcut @shortcutArgs
        }
        else {
            Write-Verbose "Shortcut $($shortcutArgs.Path) exists."
        }
    }
}

Stop-Transcript
