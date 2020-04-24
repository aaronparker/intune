<#
        .SYNOPSIS
            Forces the Microsoft Store to download app updates.
 
        .NOTES
 	        NAME: Invoke-StoreUpdates.ps1
	        VERSION: 1.0
	        AUTHOR: Aaron Parker
	        TWITTER: @stealthpuppy
 
        .LINK
            http://stealthpuppy.com
    #>
[CmdletBinding(DefaultParameterSetName = "Blacklist")]
Param ()

# Start logging
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Invoke Store updates
Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | `
    Invoke-CimMethod -MethodName "UpdateScanMethod" -Verbose

# Stop transript
Stop-Transcript
