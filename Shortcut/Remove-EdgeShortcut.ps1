<#
    .SYNOPSIS
        Deletes the Microsoft Edge shortcut from the Public desktop
#>
[CmdletBinding()]
Param()

$Shortcut = "$env:Public\Desktop\Microsoft Edge.lnk"
If (Test-Path -Path $Shortcut) { Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue }
