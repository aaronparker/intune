#Requires -Version 2
#Requires -RunAsAdministrator
<#PSScriptInfo
    .VERSION 1.0
    .GUID dbf4908f-a5b6-4ce5-89fc-b54317b99896
    .AUTHOR Aaron Parker, @stealthpuppy
    .COMPANYNAME stealthpuppy
    .COPYRIGHT Aaron Parker, https://stealthpuppy.com
    .TAGS OneDrive
    .LICENSEURI https://github.com/aaronparker/Intune/blob/master/LICENSE
    .PROJECTURI https://github.com/aaronparker/Intune 
    .ICONURI 
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES
    .PRIVATEDATA 
#>
<# 
    .DESCRIPTION 
        Downloads and installs the OneDrive Sync client preview version and installs the OneDrive client per-machine.

    .LINK
        https://docs.microsoft.com/en-us/onedrive/per-machine-installation
#> 
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $OneDriveUri = "https://go.microsoft.com/fwlink/?linkid=2083517",
    # URI to the preview OneDrive client

    [Parameter()]
    [string] $OneDriveSetup = $(Join-Path "$env:Temp" "OneDriveSetup.exe"),
    # Location where the OneDrive client will be downloaded to

    [Parameter()]
    [switch] $Force = [switch]::Present
    # Force install of the preview client even if the installed client is higher.
)

#region Functions
Function Get-FileMetadata {
    <#
        .SYNOPSIS
            Get file metadata from files in a target folder.
        
        .DESCRIPTION
            Retreives file metadata from files in a target path, or file paths, to display information on the target files.
            Useful for understanding application files and identifying metadata stored in them. Enables the administrator to view metadata for application control scenarios.

        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy
        
        .OUTPUTS
            [System.Array]

        .PARAMETER Path
            A target path in which to scan files for metadata.

        .PARAMETER Include
            Gets only the specified items.

        .EXAMPLE
            Get-FileMetadata -Path "C:\Users\aaron\AppData\Local\GitHubDesktop"

            Description:
            Scans the folder specified in the Path variable and returns the metadata for each file.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([Array])]
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, `
                HelpMessage = 'Specify a target path, paths or a list of files to scan for metadata.')]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,

        [Parameter(Mandatory = $False, Position = 1, ValueFromPipeline = $False, `
                HelpMessage = 'Gets only the specified items.')]
        [Alias('Filter')]
        [string[]]$Include = @('*.exe', '*.dll', '*.ocx', '*.msi', '*.ps1', '*.vbs', '*.js', '*.cmd', '*.bat')
    )
    Begin {
        # Measure time taken to gather data
        $StopWatch = [system.diagnostics.stopwatch]::StartNew()

        # RegEx to grab CN from certificates
        $FindCN = "(?:.*CN=)(.*?)(?:,\ O.*)"

        Write-Verbose -Message "Beginning metadata trawling."
        $Files = @()
    }
    Process {
        # For each path in $Path, check that the path exists
        ForEach ($Loc in $Path) {
            If (Test-Path -Path $Loc -IsValid) {
                # Get the item to determine whether it's a file or folder
                If ((Get-Item -Path $Loc).PSIsContainer) {
                    # Target is a folder, so trawl the folder for .exe and .dll files in the target and sub-folders
                    Write-Verbose -Message "Getting metadata for files in folder: $Loc"
                    $items = Get-ChildItem -Path $Loc -Recurse -Include $Include
                }
                Else {
                    # Target is a file, so just get metadata for the file
                    Write-Verbose -Message "Getting metadata for file: $Loc"
                    $items = Get-Item -Path $Loc
                }

                # Create an array from what was returned for specific data and sort on file path
                $Files += $items | Select-Object @{Name = "Path"; Expression = {$_.FullName}}, `
                @{Name = "Owner"; Expression = {(Get-Acl -Path $_.FullName).Owner}}, `
                @{Name = "Vendor"; Expression = {$(((Get-AcDigitalSignature -Path $_ -ErrorAction SilentlyContinue).Subject -replace $FindCN, '$1') -replace '"', "")}}, `
                @{Name = "Company"; Expression = {$_.VersionInfo.CompanyName}}, `
                @{Name = "Description"; Expression = {$_.VersionInfo.FileDescription}}, `
                @{Name = "Product"; Expression = {$_.VersionInfo.ProductName}}, `
                @{Name = "ProductVersion"; Expression = {$_.VersionInfo.ProductVersion}}, `
                @{Name = "FileVersion"; Expression = {$_.VersionInfo.FileVersion}}
            }
            Else {
                Write-Error "Path does not exist: $Loc"
            }
        }
    }
    End {
        # Return the array of file paths and metadata
        $StopWatch.Stop()
        Write-Verbose -Message "Metadata trawling complete. Script took $($StopWatch.Elapsed.TotalMilliseconds) ms to complete."
        Write-Output ($Files | Sort-Object -Property Path)
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
        [string] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ArgumentList
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
                if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
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
#endregion


# Start log file
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile
$VerbosePreference = "Continue"

# Download and install the OneDrive sync client
Write-Warning "This script downloads and installs a preview version of the OneDrive sync client."
try {
    $downloadStatus = $True
    Write-Verbose -Message "Downloading to $OneDriveSetup"
    Invoke-WebRequest -Uri $OneDriveUri -OutFile $OneDriveSetup -UseBasicParsing -Verbose
}
catch {
    Throw "Failed to download the OneDrive installer."
    $downloadStatus = $False
}
finally {
    If ($downloadStatus) {
        $file = Get-FileMetaData -Path $OneDriveSetup -Verbose
        Write-Verbose -Message "Successfully downloaded OneDrive version: $($file.FileVersion)"

        $OneDriveRegistry = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "Version"
        Write-Verbose -Message "Installed OneDrive client is: $($OneDriveRegistry.Version)"

        # Only install if the installed version lower than the downloaded version or '-Force $True' is specified
        If (([System.Version]$OneDriveRegistry.Version -lt [System.Version]$file.FileVersion) -or ($Force.IsPresent)) {
            Write-Verbose -Message "Installing OneDrive version: $($file.FileVersion)"
            Invoke-Process -FilePath $OneDriveSetup -ArgumentList "/allusers /silent" -Verbose
        }
        Else {
            Write-Verbose -Message "Skipping installation."
        }

        # Clean up the downloaded file
        Remove-Item -Path $OneDriveSetup -Force -Verbose
    }
    Else {
        Write-Verbose -Message "Download has failed. Installation skipped."
    }
}

# Stop logging
Stop-Transcript
