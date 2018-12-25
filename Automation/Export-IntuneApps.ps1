[CmdletBinding()]
Param ()

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.windowsMobileMSI" } | `
    Export-Csv -Path .\IntuneMsiApps.csv -NoTypeInformation

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.microsoftStoreForBusinessApp" } | `
    Select-Object '@odata.type', id, displayName, publisher, productKey | `
    Export-Csv -Path .\IntuneStoreApps.csv -NoTypeInformation

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.iosStoreApp" } | `
    Select-Object "@odata.type", id, displayName, publisher, isFeatured, bundleId, appStoreUrl | `
    Export-Csv -Path .\IntuneIosApps.csv -NoTypeInformation

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.managedIOSStoreApp" } | `
    Select-Object "@odata.type", id, displayName, publisher, isFeatured, publishingState, appAvailability, bundleId, appStoreUrl | `
    Export-Csv -Path .\IntuneManagedIosApps.csv -NoTypeInformation

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.androidStoreApp" } | `
    Select-Object "@odata.type", id, displayName, publisher, isFeatured, packageId, appStoreUrl | `
    Export-Csv -Path .\IntuneAndroidApps.csv -NoTypeInformation

Get-IntuneMobileApp | `
    Where-Object { $_.'@odata.type' -eq "#microsoft.graph.managedAndroidStoreApp" } | `
    Select-Object "@odata.type", id, displayName, publisher, isFeatured, publishingState, appAvailability, packageId, appStoreUrl | `
    Export-Csv -Path .\IntuneManagedAndroidApps.csv -NoTypeInformation
