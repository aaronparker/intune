<#
    .SYNOPSIS
        Set Monitor brightness level.
        Some device models set display level to 100% during OOBE

    .NOTES
        https://techibee.com/powershell/powershell-change-monitor-brightness
#>

[CmdletBinding()]
param (
    [ValidateRange(0, 100)]
    [System.Int32] $Brightness = 30
)            

try {
    $params = @{
        Namespace   = "RootWmi"
        Class       = "WmiMonitorBrightnessMethods"
        ErrorAction = "SilentlyContinue"
    }
    $Monitor = Get-WmiObject @params
    $Monitor.WmiSetBrightness(5, $Brightness)
    exit 0
}
catch {
    throw $_
}
