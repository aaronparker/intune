# User Experience Virtualization

* `Invoke-Uev.ps1` - a Proactive Remediation that enables the UE-V client, and downloads and registers a set of templates from an Azure storage account
* `Detect-Uev.ps1` - a Proactive Remediation to detect the status of the UE-V client
* `./templates` - custom UE-V templates
* `UserExperienceVirtualization-Profile.json` - an Intune Settings Catalog device configuration profile to configure User Experience Virtualization on Windows PCs

## Tests

[![Build Status](https://dev.azure.com/stealthpuppyLab/Uev/_apis/build/status/aaronparker.intune?branchName=main)](https://dev.azure.com/stealthpuppyLab/Uev/_build/latest?definitionId=15&branchName=main)

* `Publish-Templates.yml` - an Azure Pipeline that validates UE-V templates and uploads the templates to blob storage on an Azure storage account
* `./tests` - Pester tests to validate the UE-V templates

## Other scripts

* `Get-AzureBlobItem.ps1` - a function that returns items from Azure blob storage
