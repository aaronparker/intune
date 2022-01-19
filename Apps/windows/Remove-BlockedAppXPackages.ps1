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
            PS C:\> .\Remove-AppxApps.ps1 -Operation BlockList

            Remove the default list of BlockListed AppX packages stored in the function.

        .EXAMPLE
            PS C:\> .\Remove-AppxApps.ps1 -Operation AllowList

            Remove the default list of AllowListed AppX packages stored in the function.

         .EXAMPLE
            PS C:\> .\Remove-AppxApps.ps1 -Operation BlockList -BlockList "Microsoft.3DBuilder_8wekyb3d8bbwe", "Microsoft.XboxApp_8wekyb3d8bbwe"

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

begin {
    # Get elevated status. If elevated we'll remove packages from all users and provisioned packages
    [System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

process {
    # Get the AppX package object by passing the string to the left of the underscore
    # to Get-AppxPackage and passing the resulting package object to Remove-AppxPackage
    $Packages = Get-AppxPackage | Where-Object { $_.PackageFamilyName -in $BlockList }
    try {
        $Status = 0
        $Packages | Remove-AppxPackage -ErrorAction "SilentlyContinue"
    }
    catch [System.Exception] {
        Write-Output $_.Exception.Message
        $Status = 1
    }

    If ($Elevated) {
        $Packages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in ($BlockList -split "_") }
        ForEach ($Package in $Packages) {
            try {
                $Status = 0
                Remove-AppxProvisionedPackage -Online -PackageName $Package.PackageName -ErrorAction "SilentlyContinue"
            }
            catch [System.Exception] {
                Write-Output $_.Exception.Message
                $Status = 1
            }
        }
    }
}

end {
    Exit $Status
}
