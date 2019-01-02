    
$policy = Get-Content -Path .\Prod-Win10All-Compliance-windows10CompliancePolicy.json -Raw | `
    ConvertFrom-Json | `
    Select-Object -ExcludeProperty '@odata.type', id, createdDateTime, lastModifiedDateTime, displayName, `
    version, deviceCompliancePolicyId, deviceCompliancePolicyODataType, windows10CompliancePolicyReferenceUrl

$policyParams = $policy.PSObject.Properties | Where-Object { $null -ne $_.Value } | Format-Table Name, Value
    
New-IntuneDeviceCompliancePolicy -windows10CompliancePolicy -displayName "Template-Win10All-Compliance" @policyParams

$policyParams = @{
    passwordRequired                    = $True
    passwordBlockSimple                 = $False
    passwordRequiredToUnlockFromIdle    = $False
    passwordRequiredType                = "deviceDefault"
    requireHealthyDeviceReport          = $False
    osMinimumVersion                    = "10.0.17134"
    earlyLaunchAntiMalwareDriverEnabled = $False
    bitLockerEnabled                    = $True
    secureBootEnabled                   = $True
    codeIntegrityEnabled                = $True
    storageRequireEncryption            = $True
}

New-IntuneDeviceCompliancePolicy -windows10CompliancePolicy <SwitchParameter>
-assignments <object>
-bitLockerEnabled <bool>
-codeIntegrityEnabled <bool>
-createdDateTime <DateTimeOffset>
    -description <string>
    -deviceSettingStateSummaries <object>
    -deviceStatuses <object> 
    -deviceStatusOverview <object> 
    -displayName <string> 
    -earlyLaunchAntiMalwareDriverEnabled <bool> 
    -lastModifiedDateTime <DateTimeOffset> 
    -mobileOsMaximumVersion <string> 
    -mobileOsMinimumVersion <string>
    -osMaximumVersion <string> 
    -osMinimumVersion <string> 
    -passwordBlockSimple <bool> 
    -passwordExpirationDays <int> 
    -passwordMinimumCharacterSetCount <int> 
    -passwordMinimumLength <int> 
    -passwordMinutesOfInactivityBeforeLock <int> 
    -passwordPreviousPasswordBlockCount <int> 
    -passwordRequired <bool> 
    -passwordRequiredToUnlockFromIdle <bool> 
    -passwordRequiredType <string> 
    -requireHealthyDeviceReport <bool> 
    -scheduledActionsForRule <object> 
    -secureBootEnabled <bool> 
    -storageRequireEncryption <bool> 
    -userStatuses <object> 
    -userStatusOverview <object>
    -version <int>
    <CommonParameters>