<#
    .SYNOPSIS
        Deletes shortcuts from the Public desktop
#>
[CmdletBinding()]
Param()

$PublicDesktop = "$env:Public\Desktop"
$FileTypes = "*.lnk"
$Shortcuts = Get-ChildItem -Path $PublicDesktop -Filter $FileTypes
If ($Null -ne $Shortcuts) { $Shortcuts | Remove-Item -Force -ErrorAction SilentlyContinue }
