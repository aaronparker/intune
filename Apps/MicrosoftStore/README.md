# Microsoft Store apps

Scripts for managing Microsoft Store apps in Intune. In the current implementation, authentication is performed against an Azure AD app registration. The `DeviceManagementApps.ReadWrite.All` permission is required and authentication details are expected in JSON in the following format:

```json
{
    "TenantId": "cfa922be-fe9b-4728-861f-640c60f6cd6c",
    "ClientID": "3c3c8ac2-c471-4638-b071-07de39b5a6a3",
    "ClientSecret": "AeCCF~QLozAm9BbJTGiuZiIXMBtxa6QFSa68XcWp"
}
```

## Import Microsoft Store apps

`Import-MicrosoftStoreAppsFromCsv.ps1` can be used to import a list of Microsoft Store apps into an Intune tenant. This script takes a simple CSV file as input that includes the package display name and identifier, and a single assignment per app. This will then import the list of apps and configure the assignments.

```powershell
.\Import-MicrosoftStoreAppsFromCsv.ps1 -AppList .\StoreApps.csv
```

## Migrate from Microsoft Store for Business to Microsoft Store apps

These scripts can be used for migrate existing Microsoft Store for Business apps to the new Microsoft Store apps. This approach will export a list of the existing Microsoft Store for Business apps including assignments to JSON files. These can then be used to import the same applications including application icons and assignments to Microsoft Store apps. You can then delete the Microsoft Store for Business apps.

To export the current list of Microsoft Store for Business apps to a JSON file per app, use the following commands:

```powershell
.\Get-MicrosoftStoreForBusinessApps.ps1 | % { $_ | .\Get-MobileAppAssignments.ps1 | Out-File -FilePath ".\$($_.DisplayName).json" }
```

We can then import these applications into the new Microsoft Store app format including assignments and the appropriate icon for the app with the following command:

```powershell
Get-ChildItem -Path "*.json" -Exclude "auth.json" | .\Import-MicrosoftStoreAppsFromJson.ps1
```

Once complete, you can then delete the Microsoft Store for Business Apps (use `-Confirm:$false` to actually delete the apps):

```powershell
$Apps = .\Get-MicrosoftStoreForBusinessApps.ps1
$Apps | .\Remove-MobileApp.ps1 -WhatIf
```
