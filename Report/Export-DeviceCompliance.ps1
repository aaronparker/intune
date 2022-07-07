<#
    .SYNOPSIS
        Compile a report on per device compliance settings
#>
[CmdletBinding()]
param ()

<#
# Configure an app registration with permissions to the DeviceManagement API
$authparams = @{
    ClientId     = "db8dbb7a-40a4-444b-8912-6f14f80816b7"
    TenantId     = "tenant.onmicrosoft.com"
    ClientSecret = ("sdflkjsdflkjsdfsdfsdfsdfsdf" | ConvertTo-SecureString -AsPlainText -Force)
}
$auth = Get-MsalToken @authParams
#>

$settings = @(
    "Windows10CompliancePolicy.ActiveFirewallRequired",
    "Windows10CompliancePolicy.AntiSpywareRequired",
    "Windows10CompliancePolicy.AntivirusRequired",
    "Windows10CompliancePolicy.BitLockerEnabled",
    "Windows10CompliancePolicy.CodeIntegrityEnabled",
    "Windows10CompliancePolicy.DefenderEnabled",
    "Windows10CompliancePolicy.OsMinimumVersion",
    #"Windows10CompliancePolicy.PasswordBlockSimple",
    #"Windows10CompliancePolicy.PasswordMinimumLength",
    #"Windows10CompliancePolicy.PasswordMinutesOfInactivityBeforeLock",
    #"Windows10CompliancePolicy.PasswordPreviousPasswordBlockCount",
    "Windows10CompliancePolicy.RtpEnabled",
    "Windows10CompliancePolicy.SecureBootEnabled",
    "Windows10CompliancePolicy.SignatureOutOfDate",
    "Windows10CompliancePolicy.StorageRequireEncryption",
    "Windows10CompliancePolicy.TpmRequired"
)

Remove-Variable -Name ComplianceTable -ErrorAction "SilentlyContinue"
ForEach ($setting in $settings) {
    $Url = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicySettingStateSummaries/$setting/deviceComplianceSettingStates"
    $params = @{
        Headers = @{Authorization = "Bearer $($auth.AccessToken)" }
        Uri     = $Url
        Method  = "Get"
    }
    $query = Invoke-RestMethod @params

    If ($Null -eq $ComplianceTable) {
        [System.Array] $ComplianceTable = @()
        ForEach ($item in $query.value) {
            #Write-Host "Add $($item.setting) to $($item.deviceName)."
            $device = [PSCustomObject] @{
                deviceId          = $item.deviceId
                deviceName        = $item.deviceName
                userPrincipalName = $item.userPrincipalName
                deviceModel       = $item.deviceModel
            }
            $device | Add-Member -NotePropertyName $($item.setting) -NotePropertyValue $item.state -Force
            $ComplianceTable += $device
        }
    }
    Else {
        ForEach ($item in $query.value) {
            $index = [array]::IndexOf($ComplianceTable.deviceId, $item.deviceId)
            If ($ComplianceTable[$index].PSObject.Properties.name -contains $($item.setting)) {
                #Write-Host "Device $($ComplianceTable[$index].deviceName) already has property $($item.setting)."
            }
            Else {
                $ComplianceTable[$index] | Add-Member -NotePropertyName $($item.setting) -NotePropertyValue $item.state -Force
            }
        }
    }
}

$ComplianceTable | Export-Csv -Path "ComplianceTable.csv" -Delimiter ","
