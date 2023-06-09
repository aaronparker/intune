<#
    .SYNOPSIS
        Create intunemac packages from input paths

    .NOTES
        New-IntuneMac.ps1
        Author: Aaron Parker
	    Twitter: @stealthpuppy

    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Script run locally.")]
Param (
    [Parameter()]
    [System.String] $Path = "/Users/aaron/Temp/macOS-Apps",

    [Parameter(
        Position = 0,
        ValueFromPipeline)]
    [System.String[]] $Packages
)

begin {
    # If we are running on macOS, then continue
    if ($PSVersionTable.OS -like "Darwin*") {}
    else {
        throw "This script needs to be run on macOS to use the IntuneAppUtil wrapping tool."
    }

    #region Get latest IntuneAppUtil binary
    $uri = "https://raw.githubusercontent.com/msintuneappsdk/intune-app-wrapping-tool-mac/v1.2/IntuneAppUtil"
    $binary = Join-Path -Path $Path -ChildPath (Split-Path -Path $uri -Leaf)
    if (!(Test-Path -Path $binary)) {
        try {
            $ProgressPreference = "SilentlyContinue"
            $params = @{
                Uri             = $uri
                OutFile         = $binary
                UseBasicParsing = $true
                ErrorAction     = "SilentlyContinue"
            }
            Invoke-WebRequest @params
        }
        catch {
            throw $_
        }
        if (Test-Path -Path $binary) {
            try {
                chmod +x $binary
            }
            catch {
                Write-Warning -Message "Failed to set execute permission on: $binary."
                throw $_
            }
        }
    }
    #endregion
}

process {
    foreach ($Package in $Packages) {
        if ((Test-Path -Path $Package) -and $Package -match "\.pkg$") {

            try {
                # Convert the Pkg to IntuneMac format
                $params = @{
                    FilePath     = $binary
                    ArgumentList = "-c $Package -o $Path -v"
                    ErrorAction  = "SilentlyContinue"
                    Verbose      = $true
                }
                Start-Process @params
            }
            catch {
                throw $_
            }
        }
        else {
            Write-Warning -Message "Cannot find path or package not in .pkg format: $Package"
        }
    }
}
