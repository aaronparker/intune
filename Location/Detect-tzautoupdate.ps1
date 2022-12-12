<#
    Get the value of Start in tzautoupdate
#>

$Key = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
$Name = "Start"

# The value we are expecting
[System.Int32] $Value = 3

# Get the current value
try {
    $params = @{
        Path        = $Key
        Name        = $Name
        ErrorAction = "SilentlyContinue"
    }
    $Property = Get-ItemProperty @params
}
catch {
    throw [System.Management.Automation.ItemNotFoundException] "Failed to retrieve value for $Name with $($_.Exception.Message)"
}

if ($Property.$Name -eq $Value) {
    return 0
}
else {
    return 1
}
