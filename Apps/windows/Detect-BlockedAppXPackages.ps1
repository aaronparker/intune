<#
        .SYNOPSIS
            Removes a specified list of AppX packages from the current system.

        .DESCRIPTION
            Removes a specified list of AppX packages from the current user account and the local system to prevent new installs of in-built apps when new users log onto the system.

            If the script is run elevated, it will remove provisioned packages from the system and packages from all user accounts. Otherwise only packages for the current user account will be removed.

        .PARAMETER BlockList
            Specify an array of AppX packages to 'BlockList' or remove from the current Windows instance, all other apps will remain installed. The script will use the BlockList by default.

            The default BlockList is primarily aimed at configuring AppX packages for physical PCs.

         .EXAMPLE
            PS C:\> .\Remove-AppxApps.ps1 -BlockList "Microsoft.3DBuilder_8wekyb3d8bbwe", "Microsoft.XboxApp_8wekyb3d8bbwe"

            Remove a specific set of AppX packages a specified in the -BlockList argument.

        .NOTES
 	        NAME: Remove-AppxApps.ps1
	        VERSION: 3.0
	        AUTHOR: Aaron Parker
	        TWITTER: @stealthpuppy

        .LINK
            https://stealthpuppy.com
#>
[CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = "BlockList")]
param (
    [Parameter(Mandatory = $False, ParameterSetName = "BlockList", HelpMessage = "Specify an AppX package or packages to remove.")]
    [System.String[]] $BlockList = (
        "MicrosoftTeams_8wekyb3d8bbwe", # Microsoft Teams package on Windows 11
        "Microsoft.XboxApp_8wekyb3d8bbwe", # Xbox Console Companion
        "Microsoft.BingNews_8wekyb3d8bbwe", # Microsoft News
        "Microsoft.GamingApp_8wekyb3d8bbwe" # Microsoft Xbox app?
    )
)

begin {}

process {
    # Remove the apps; Walk through each package in the array
    $Packages = Get-AppxPackage | Where-Object { $_.PackageFamilyName -in $BlockList }
    If ($Packages.Count -ge 1) {
        Write-Host "Found $($Packages.Count) packages to remove."
        Exit 1
    }
    Else {
        Exit 0
    }
}

end {}
