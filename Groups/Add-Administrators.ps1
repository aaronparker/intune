<#
    Adds the primary user of the device to the local Administrators group
#>
[CmdletBinding()]
param()

function Get-Key {
    try {
        $EnrollmentsKey = "HKLM:\SOFTWARE\Microsoft\Enrollments\"
        $MatchingKey = foreach ($Key in (Get-ChildItem -Path $EnrollmentsKey | Where-Object { $_.PSIsContainer -eq $true })) {
            $Key | Where-Object { ($_.Property -match "ProviderID") -and ($_.Property -match "UPN") -and ($_.Property -match "AADTenantID") }
        }
    }
    catch {
        $MatchingKey = $Null
        throw "Failed to return key."
    }
    Write-Output -InputObject $MatchingKey
}

$MatchingKey = Get-Key
if ($Null -ne $MatchingKey) {
    $Upn = $MatchingKey.GetValue("UPN")
    if ($Null -ne $Upn) {
        if (($MatchingKey.GetValue("ProviderID") -match "MS DM Server") -and ($MatchingKey.GetValue("AADResourceID") -match "https://manage.microsoft.com/")) {
            try {
                $String = "Attempting to add $Upn to Administrators."
                $params = @{
                    Group       = "Administrators"
                    Member      = "AzureAD\$Upn"
                    ErrorAction = "Stop"
                }
                Add-LocalGroupMember @params
            }
            catch {
                $String += " $($_.Exception.Message)"
                $String
                exit 1
            }
            $String += " Successfully added $Upn to Administrators."
            $String
            exit 0
        }
        else {
            "No matching values for ProviderID and AADResourceID."
            exit 1
        }
    }
    else {
        "No value for UPN. Could be multi-user / shared device."
        exit 1
    }
}
else {
    "Failed to return a matching key with ProviderID and AADResourceID."
    exit 1
}
