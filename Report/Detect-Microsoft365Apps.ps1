# Obtain Office information from WMI 
try {
    $Office = Get-WmiObject -Class "Win32_InstalledWin32Program" | `
        Where-Object { $_.Name -match "Microsoft 365|Microsoft Office" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } -ErrorAction "SilentlyContinue" | `
        Select-Object -Property "Name", "Version", "Vendor"
}
catch {
    Write-Output "WMI query failed: Win32_InstalledWin32Program."
    Exit 1
}

# Check for returned values, if null, write output and exit 1
If ($Office -gt $null) {

    # Write antivirus product name out for Proactive remediations display purposes and set exit success
    ForEach ($item in $Office) {
        Write-Output "$($item.Name), $($item.Version)"
    }
    Exit 0
}
Else {
    Write-Output "WMI query failed: Win32_InstalledWin32Program."
    Exit 1
}
