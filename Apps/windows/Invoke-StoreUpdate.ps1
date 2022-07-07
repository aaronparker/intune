<#
        .SYNOPSIS
            Invokes the Microsoft Store to download app updates.

        .NOTES
 	        NAME: Invoke-StoreUpdates.ps1
	        VERSION: 1.0
	        AUTHOR: Aaron Parker
	        TWITTER: @stealthpuppy

        .LINK
            http://stealthpuppy.com
#>
[CmdletBinding()]
param ()

# Invoke Store updates
$params = @{
    Namespace = "root\cimv2\mdm\dmmap"
    ClassName = "MDM_EnterpriseModernAppManagement_AppManagement01"
}
Get-CimInstance @params | Invoke-CimMethod -MethodName "UpdateScanMethod"
