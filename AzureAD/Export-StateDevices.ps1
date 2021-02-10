

$Users = Get-AzureADUser -All $true | Select-Object UserPrincipalName, ObjectId

ForEach ($User in $Users) {
    Get-AzureADUserRegisteredDevice -ObjectId $user.ObjectId | ForEach-Object {
        $Output = [PSCustomObject] @{
            DeviceOwner                   = $user.UserPrincipalName
            DeviceName                    = $_.DisplayName
            DeviceOSType                  = $_.DeviceOSType
            ApproximateLastLogonTimeStamp = $_.ApproximateLastLogonTimeStamp
        }
        Write-Output -InputObject $Output
    }
}


#$dt = [datetime]’2017/01/01’
#Get-MsolDevice -all -LogonTimeBefore $dt | select-object -Property Enabled, DeviceId, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | export-csv devicelist-olderthan-Jan-1-2017-summary.csv
