<#
    Set time and time zone to automatic
#>

# Set time automatically
$params = @{
    Path  = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
    Name  = "Start"
    Value = "3"
}
Set-ItemProperty @params

# Set time zone automatically
$params = @{
    Path  = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
    Name  = "Type"
    Value = "NTP"
}
Set-ItemProperty @params

# Allow apps access to your location
$params = @{
    Path  = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged"
    Name  = "Value"
    Value = "Allow"
}
Set-ItemProperty @params
