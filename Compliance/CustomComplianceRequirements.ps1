# Return details of the Cisco AMP and Cisco Orbital services to ensure the services are running
$Hash = @{}
foreach ($Service in "CiscoAMP", "CiscoOrbital") {
    $ServiceStatus = Get-Service -Name $Service -ErrorAction "SilentlyContinue"
    if ($null -ne $ServiceStatus) {
        $Hash.Add("$($Service)ServiceStatus", $ServiceStatus.Status.ToString())
    }
    else {
        $Hash.Add("$($Service)ServiceStatus", $null)
    }
}
return $Hash | ConvertTo-Json -Compress