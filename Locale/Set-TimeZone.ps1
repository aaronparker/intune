<#
    .SYNOPSIS
        Sets the device time zone
#>
[CmdletBinding()]
param (
    [System.String] $TimeZone = "AUS Eastern Standard Time"
)
try {
    Set-Timezone -Name $TimeZone
}
catch {
    Return 1
    Break
}
Return 0
