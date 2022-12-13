<#
    Set the value of Start in tzautoupdate
#>

$Key = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
$Name = "Start"

# The value we are expecting
[System.Int32] $Value = 3

# Set the current value
$params = @{
    Path        = $Key
    Name        = $Name
    Value       = $Value
    ErrorAction = "Stop"
}
Set-ItemProperty @params | Out-Null

$params = @{
    Path = $Key
    Name = $Name
}
$Property = Get-ItemProperty @params
if ($Property.$Name -eq $Value) {
    Start-Service -Name "tzautoupdate"
    return 0
}
else {
    return 1
}
