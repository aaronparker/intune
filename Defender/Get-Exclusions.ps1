function Get-Exclusions {
    $Prefs = Get-MpPreference
    $Prefs.ExclusionExtension | ForEach-Object { [PSCustomObject]@{ Item = $_; Type = "Extension" } }
    $Prefs.ExclusionProcess | ForEach-Object { [PSCustomObject]@{ Item = $_; Type = "Process" } }
    $Prefs.ExclusionPath | ForEach-Object { [PSCustomObject]@{ Item = $_; Type = "Path" } }
    $Prefs.ExclusionIpAddress | ForEach-Object { [PSCustomObject]@{ Item = $_; Type = "IpAddress" } }
}

Get-Exclusions | ConvertTo-Csv -NoTypeInformation
