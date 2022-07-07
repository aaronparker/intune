# Requires -Version 3
<#
    .SYNOPSIS
        Creates a scheduled task to implement folder redirection for.

    .NOTES
        Name: Redirect-Folders.ps1
        Author: Aaron Parker
        Site: https://stealthpuppy.com
        Twitter: @stealthpuppy
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
param ()

# Log file
$VerbosePreference = "Continue"
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$LogFile = "$env:LocalAppData\IntuneScriptLogs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

Function Set-KnownFolderPath {
    <#
        .SYNOPSIS
            Sets a known folder's path using SHSetKnownFolderPath.
        .PARAMETER KnownFolder
            The known folder whose path to set.
        .PARAMETER Path
            The target path to redirect the folder to.
        .NOTES
            Forked from: https://gist.github.com/semenko/49a28675e4aae5c8be49b83960877ac5
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AddNewPrograms', 'AdminTools', 'AppUpdates', 'CDBurning', 'ChangeRemovePrograms', 'CommonAdminTools', 'CommonOEMLinks', 'CommonPrograms', `
                'CommonStartMenu', 'CommonStartup', 'CommonTemplates', 'ComputerFolder', 'ConflictFolder', 'ConnectionsFolder', 'Contacts', 'ControlPanelFolder', 'Cookies', `
                'Desktop', 'Documents', 'Downloads', 'Favorites', 'Fonts', 'Games', 'GameTasks', 'History', 'InternetCache', 'InternetFolder', 'Links', 'LocalAppData', `
                'LocalAppDataLow', 'LocalizedResourcesDir', 'Music', 'NetHood', 'NetworkFolder', 'OriginalImages', 'PhotoAlbums', 'Pictures', 'Playlists', 'PrintersFolder', `
                'PrintHood', 'Profile', 'ProgramData', 'ProgramFiles', 'ProgramFilesX64', 'ProgramFilesX86', 'ProgramFilesCommon', 'ProgramFilesCommonX64', 'ProgramFilesCommonX86', `
                'Programs', 'Public', 'PublicDesktop', 'PublicDocuments', 'PublicDownloads', 'PublicGameTasks', 'PublicMusic', 'PublicPictures', 'PublicVideos', 'QuickLaunch', `
                'Recent', 'RecycleBinFolder', 'ResourceDir', 'RoamingAppData', 'SampleMusic', 'SamplePictures', 'SamplePlaylists', 'SampleVideos', 'SavedGames', 'SavedSearches', `
                'SEARCH_CSC', 'SEARCH_MAPI', 'SearchHome', 'SendTo', 'SidebarDefaultParts', 'SidebarParts', 'StartMenu', 'Startup', 'SyncManagerFolder', 'SyncResultsFolder', `
                'SyncSetupFolder', 'System', 'SystemX86', 'Templates', 'TreeProperties', 'UserProfiles', 'UsersFiles', 'Videos', 'Windows')]
        [System.String] $KnownFolder,

        [Parameter(Mandatory = $true)]
        [System.String] $Path
    )

    # Define known folder GUIDs
    $KnownFolders = @{
        'Contacts'       = '56784854-C6CB-462b-8169-88E350ACB882';
        'Cookies'        = '2B0F765D-C0E9-4171-908E-08A611B84FF6';
        'Desktop'        = @('B4BFCC3A-DB2C-424C-B029-7FE99A87C641');
        'Documents'      = @('FDD39AD0-238F-46AF-ADB4-6C85480369C7', 'f42ee2d3-909f-4907-8871-4c22fc0bf756');
        'Downloads'      = @('374DE290-123F-4565-9164-39C4925E467B', '7d83ee9b-2244-4e70-b1f5-5393042af1e4');
        'Favorites'      = '1777F761-68AD-4D8A-87BD-30B759FA33DD';
        'Games'          = 'CAC52C1A-B53D-4edc-92D7-6B2E8AC19434';
        'GameTasks'      = '054FAE61-4DD8-4787-80B6-090220C4B700';
        'History'        = 'D9DC8A3B-B784-432E-A781-5A1130A75963';
        'InternetCache'  = '352481E8-33BE-4251-BA85-6007CAEDCF9D';
        'InternetFolder' = '4D9F7874-4E0C-4904-967B-40B0D20C3E4B';
        'Links'          = 'bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968';
        'Music'          = @('4BD8D571-6D19-48D3-BE97-422220080E43', 'a0c69a99-21c8-4671-8703-7934162fcf1d');
        'NetHood'        = 'C5ABBF53-E17F-4121-8900-86626FC2C973';
        'OriginalImages' = '2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39';
        'PhotoAlbums'    = '69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C';
        'Pictures'       = @('33E28130-4E1E-4676-835A-98395C3BC3BB', '0ddd015d-b06c-45d5-8c4c-f59713854639');
        'QuickLaunch'    = '52a4f021-7b75-48a9-9f6b-4b87a210bc8f';
        'Recent'         = 'AE50C081-EBD2-438A-8655-8A092E34987A';
        'RoamingAppData' = '3EB685DB-65F9-4CF6-A03A-E3EF65729F3D';
        'SavedGames'     = '4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4';
        'SavedSearches'  = '7d1d3a04-debb-4115-95cf-2f29da2920da';
        'StartMenu'      = '625B53C3-AB48-4EC1-BA1F-A1EF4146FC19';
        'Templates'      = 'A63293E8-664E-48DB-A079-DF759E0509F7';
        'Videos'         = @('18989B1D-99B5-455B-841C-AB7C74E4DDFC', '35286a68-3c57-41a1-bbb1-0eae73d76c95');
    }

    # Define SHSetKnownFolderPath if it hasn't been defined already
    $Type = ([System.Management.Automation.PSTypeName]'KnownFolders').Type
    If (-not $Type) {
        $Signature = @'
[DllImport("shell32.dll")]
public extern static int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
'@
        $Type = Add-Type -MemberDefinition $Signature -Name 'KnownFolders' -Namespace 'SHSetKnownFolderPath' -PassThru
    }

    # Make path, if doesn't exist
    If (!(Test-Path $Path -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($Path, ("New-Item '{0}'" -f $Path))) {
            New-Item -Path $Path -Type "Directory" -Force -Verbose
        }
    }

    # Validate the path
    If (Test-Path $Path -PathType Container) {
        # Call SHSetKnownFolderPath
        #  return $Type::SHSetKnownFolderPath([ref]$KnownFolders[$KnownFolder], 0, 0, $Path)
        ForEach ($guid in $KnownFolders[$KnownFolder]) {
            Write-Verbose "Redirecting $KnownFolders[$KnownFolder]"
            $result = $Type::SHSetKnownFolderPath([ref]$guid, 0, 0, $Path)
            If ($result -ne 0) {
                $errormsg = "Error redirecting $($KnownFolder). Return code $($result) = $((New-Object System.ComponentModel.Win32Exception($result)).message)"
                Throw $errormsg
            }
        }
    }
    Else {
        Throw New-Object System.IO.DirectoryNotFoundException "Could not find part of the path $Path."
    }

    # Fix up permissions, if we're still here
    Attrib +r $Path
    Write-Output $Path
}

Function Get-KnownFolderPath {
    <#
        .SYNOPSIS
            Gets a known folder's path using GetFolderPath.
        .PARAMETER KnownFolder
            The known folder whose path to get. Validates set to ensure only knwwn folders are passed.
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

Function Redirect-Folder {
    <#
        .SYNOPSIS
            Function exists to reduce code required to redirect each folder.
    #>
    Param (
        [Parameter(Mandatory = $true)]
        [System.String] $SyncFolder,

        [Parameter(Mandatory = $true)]
        [System.String] $GetFolder,

        [Parameter(Mandatory = $true)]
        [System.String] $SetFolder,

        [Parameter(Mandatory = $true)]
        [System.String] $Target
    )

    # Get current Known folder path
    $Folder = Get-KnownFolderPath -KnownFolder $GetFolder

    # If paths don't match, redirect the folder
    If ($Folder -ne "$SyncFolder\$Target") {
        # Redirect the folder
        Write-Verbose "Redirecting $SetFolder to $SyncFolder\$Target"
        Set-KnownFolderPath -KnownFolder $SetFolder -Path "$SyncFolder\$Target"

        # Move files/folders into the redirected folder
        Write-Verbose "Moving data from $SetFolder to $SyncFolder\$Target"
        Move-File -Source $Folder -Destination "$SyncFolder\$Target" -Log "$env:LocalAppData\RedirectLogs\Robocopy$Target.log"

        # Hide the source folder (rather than delete it)
        Attrib +h $Folder
    }
    Else {
        Write-Verbose "Folder $GetFolder matches target. Skipping redirection."
    }
}

Function Invoke-Process {
    <#PSScriptInfo 
        .VERSION 1.4 
        .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
        .AUTHOR Adam Bertram 
        .COMPANYNAME Adam the Automator, LLC 
        .TAGS Processes 
    #>
    <# 
    .DESCRIPTION 
        Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
        are lots of ways to invoke processes in PowerShell with Start-Process, Invoke-Expression, & and others but none account 
        well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
        when launching external proceses. 

        This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
        time the process returns an exit code other than 0, treat it as an error. 
    #> 
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
    )
    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true;
            PassThru               = $true;
            NoNewWindow            = $true;
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}

Function Move-File {
    <#
        .SYNOPSIS
            Moves contents of a folder with output to a log.
            Uses Robocopy to ensure data integrity and all moves are logged for auditing.
            Means we don't need to re-write functionality in PowerShell.
        .PARAMETER Source
            The source folder.
        .PARAMETER Destination
            The destination log.
        .PARAMETER Log
            The log file to store progress/output
    #>
    Param (
        $Source,
        $Destination,
        $Log
    )
    If (!(Test-Path (Split-Path $Log))) { New-Item -Path (Split-Path $Log) -ItemType Container }
    Write-Verbose "Moving data in folder $Source to $Destination."
    Robocopy.exe "$Source" "$Destination" /E /MOV /XJ /XF *.ini /R:1 /W:1 /NP /LOG+:$Log
}


# Get OneDrive sync folder
$SyncFolder = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\OneDrive\Accounts\Business1' -Name 'UserFolder' -ErrorAction SilentlyContinue
Write-Verbose "Target sync folder is $SyncFolder."

# Redirect select folders
If (Test-Path -Path $SyncFolder -ErrorAction SilentlyContinue) {
    Redirect-Folder -SyncFolder $SyncFolder -GetFolder 'Desktop' -SetFolder 'Desktop' -Target 'Desktop'
    Redirect-Folder -SyncFolder $SyncFolder -GetFolder 'MyDocuments' -SetFolder 'Documents' -Target 'Documents'
    Redirect-Folder -SyncFolder $SyncFolder -GetFolder 'MyPictures' -SetFolder 'Pictures' -Target 'Pictures'
    Redirect-Folder -SyncFolder $SyncFolder -GetFolder 'Favorites' -SetFolder 'Favorites' -Target 'Favorites'
}
Else {
    Write-Verbose "$SyncFolder does not (yet) exist. Skipping folder redirection until next logon."
}

Stop-Transcript -Verbose
