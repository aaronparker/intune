# Requires -Version 3
<#
    .SYNOPSIS
        Creates a scheduled task to implement folder redirection for.

    .NOTES
        Name: Redirect-Folders.ps1
        Author: Aaron Parker
#>
[CmdletBinding(ConfirmImpact = 'Low', HelpURI = 'https://stealthpuppy.com/', SupportsPaging = $False,
    SupportsShouldProcess = $False, PositionalBinding = $False)]
Param (
    [Parameter()] $VerbosePreference = "Continue"
)

# Log file
$stampDate = Get-Date
$LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\Redirect-Folders-" + $stampDate.ToFileTimeUtc() + ".log"
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
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Contacts', 'Desktop', 'Documents', 'Downloads', 'Favorites', 'Games', 'Links',  'Music', 'Pictures', 'Videos', )]
        [string] $KnownFolder,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    # Define known folder GUIDs
    $KnownFolders = @{
        'Contacts'       = '56784854-C6CB-462b-8169-88E350ACB882';
        'Desktop'        = @('B4BFCC3A-DB2C-424C-B029-7FE99A87C641');
        'Documents'      = @('FDD39AD0-238F-46AF-ADB4-6C85480369C7', 'f42ee2d3-909f-4907-8871-4c22fc0bf756');
        'Downloads'      = @('374DE290-123F-4565-9164-39C4925E467B', '7d83ee9b-2244-4e70-b1f5-5393042af1e4');
        'Favorites'      = '1777F761-68AD-4D8A-87BD-30B759FA33DD';
        'Games'          = 'CAC52C1A-B53D-4edc-92D7-6B2E8AC19434';
        'Links'          = 'bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968';
        'Music'          = @('4BD8D571-6D19-48D3-BE97-422220080E43', 'a0c69a99-21c8-4671-8703-7934162fcf1d');
        'Pictures'       = @('33E28130-4E1E-4676-835A-98395C3BC3BB', '0ddd015d-b06c-45d5-8c4c-f59713854639');
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
        New-Item -Path $Path -Type Directory -Force -Verbose
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
        [ValidateSet('Contacts', 'Desktop', 'Documents', 'Downloads', 'Favorites', 'Games', 'Links',  'Music', 'Pictures', 'Videos', )]
        [string] $KnownFolder
    )
    Write-Output [Environment]::GetFolderPath($KnownFolder)
}

Function Move-Files {
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

Function Redirect-Folder {
    <#
        .SYNOPSIS
            Function exists to reduce code required to redirect each folder.
    #>
    Param (
        [Parameter(Mandatory = $true)]
        [string] $SyncFolder,

        [Parameter(Mandatory = $true)]
        [string] $GetFolder,

        [Parameter(Mandatory = $true)]
        [string] $SetFolder,

        [Parameter(Mandatory = $true)]
        [string] $Target
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
        Move-Files -Source $Folder -Destination "$SyncFolder\$Target" -Log "$env:LocalAppData\RedirectLogs\Robocopy$Target.log"
        
        # Hide the source folder (rather than delete it)
        Attrib +h $Folder
    }
    Else {
        Write-Verbose "Folder $GetFolder matches target. Skipping redirection."
    }
}

# Get OneDrive sync folder
$SyncFolder = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\OneDrive\Accounts\Business1' -Name 'UserFolder'
Write-Verbose "Target sync folder is $SyncFolder."

# Redirect select folders
If (Test-Path $SyncFolder) {
    Redirect-Folder -SyncFolder $SyncFolder -GetFolder 'Favorites' -SetFolder 'Favorites' -Target 'Favorites'
}
Else {
    Write-Verbose "$SyncFolder does not (yet) exist. Skipping folder redirection until next logon."
}

Stop-Transcript -Verbose
