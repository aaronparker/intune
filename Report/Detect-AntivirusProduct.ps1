# Obtain Antivirus information from WMI
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Output required by Proactive Remediations.")]
param ()

try {
    $params = @{
        Namespace   = "root/SecurityCenter2"
        ClassName   = "AntiVirusProduct"
        ErrorAction = "SilentlyContinue"
    }
    $AntivirusProduct = Get-CimInstance @params
}
catch {
    Write-Output "CIM query failed: root\SecurityCenter2"
    exit 1
}

# Check for antivirus display name value, if null, write output and exit 1
if (-not ([System.String]::IsNullOrEmpty($($AntivirusProduct.DisplayName)))) {
    # Write antivirus product name out for proactive remediations display purposes and set exit success
    Write-Output "$($AntivirusProduct.displayName), $($AntivirusProduct.pathToSignedReportingExe)"
    exit 0
}
else {
    Write-Output "Antivirus product not found"
    exit 1
}
