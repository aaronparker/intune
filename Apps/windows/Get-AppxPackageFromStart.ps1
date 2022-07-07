<#
        .SYNOPSIS
            Returns the AppX package that correlates to the application display name on the Start menu.

        .DESCRIPTION
            Returns the AppX package object that correlates to the application display name on the Start menu.
            Returns null if the name specified is not found or the shortcut points to a non-AppX app.

        .PARAMETER Name
            Specify a shortcut display name to return the AppX package for.

        .EXAMPLE
            PS C:\> .\Get-AppxPackageFromStart.ps1 -Name "3D Viewer"

            Returns the AppX package for the shortcut '3D Viewer'.

        .NOTES
 	        NAME: Get-AppxPackageFromStart.ps1
	        VERSION: 1.2
	        AUTHOR: Aaron Parker

        .LINK
            http://stealthpuppy.com
    #>
[CmdletBinding(SupportsShouldProcess = $False)]
Param (
    [Parameter(Mandatory = $True, HelpMessage = "Specify a Start menu shortcut name.")]
    [System.String[]] $Name
)

ForEach ($Package in $Name) {
    Write-Verbose -Message "$($MyInvocation.MyCommand): Searching for: [$Package]."
    $StartPkg = Get-StartApps -Name $Package

    # If package is not Null and AppID contains !, assume that it is an AppX package
    If ($Null -ne $StartPkg) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found: [$($StartPkg.AppID)]."
        If ($StartPkg.AppID.Contains("!")) {

            # Return an AppX package object by comparing the Start menu package AppId to the PackageFamilyName up to the ! character
            Write-Verbose -Message "$($MyInvocation.MyCommand): Running: [Get-AppxPackage]."
            Write-Output -InputObject (Get-AppxPackage | Where-Object { ($StartPkg.AppID -split "!")[0] -contains $_.PackageFamilyName })
        }
    }
}
