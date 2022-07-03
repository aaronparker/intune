# User Experience Virtualization

* `Invoke-Uev.ps1` - a Proactive Remediation that enables the UE-V client, and downloads and registers a set of templates from an Azure storage account
* `Publish-Templates.yml` - an Azure Pipeline that validates UE-V templates and uploads the templates to blob storage on an Azure storage account
* `./tests` - Pester tests to validate the UE-V templates
* `./templates` - custom UE-V templates
* `Get-AzureBlobItem.ps1` - a function that returns items from Azure blob storage
