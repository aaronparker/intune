# Obtain Antivirus information from WMI 
$params = @{
    Namespace   = "Root\SecurityCenter2"
    Query       = "SELECT * FROM AntiVirusProduct"
    ErrorAction = "SilentlyContinue"
}
$AntivirusProduct = Get-WmiObject @params

# Check for returned values, if null, write output and exit 1
If ($AntiVirusProduct -gt $null) {
    # Check for antivirus display name value, if null, write output and exit 1
    If (-not ([string]::IsNullOrEmpty($($AntivirusProduct.DisplayName)))) {
        # Write antivirus product name out for proactive remediations display purposes and set exit success
        Write-Output $AntivirusProduct.displayName
        Exit 0
    }
    Else {
        Write-Output "Antivirus product not found"
        Exit 1
    }
}
Else {
    Write-Output "WMI query failed: root\SecurityCenter2"
    Exit 1
}
