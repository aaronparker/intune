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
    exit 0
}
catch {
    exit 1
}
