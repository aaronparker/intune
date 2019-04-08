#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Intune, PSWriteExcel
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Outputs configuration objects from an Intune tenant into an Excel workbook
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $FilePath = $(Join-Path (Resolve-Path $pwd) "Lendlease-Devices.xlsx")
)

# Install required modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -ErrorAction SilentlyContinue
If ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted" ) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
$modules = @('Microsoft.Graph.Intune', 'PSWriteExcel')
ForEach ($module in $modules) {
    Install-Module -Name $module
    Import-Module -Name $module
}

# Get device status report
$Devices = Get-IntuneManagedDevice | `
    Select-Object -Property userDisplayName, userPrincipalName, emailAddress, deviceName, enrolledDateTime, `
    manufacturer, model, operatingSystem, osVersion, deviceEnrollmentType, lastSyncDateTime, complianceState, deviceCategoryDisplayName, `
    managedDeviceName, managedDeviceOwnerType, deviceRegistrationState, easActivated, azureADRegistered, exchangeAccessState | `
    Sort-Object enrolledDateTime -Descending

# Write output to Excel
$Excel = New-ExcelDocument
$ExcelWorkSheet = Add-ExcelWorkSheet -ExcelDocument $Excel -WorksheetName "Devices" -Supress $False -Option 'Replace'
Add-ExcelWorksheetData -ExcelWorksheet $ExcelWorkSheet -DataTable $Devices -AutoFit -Supress $True -FreezeTopRow -TableStyle Light9
Save-ExcelDocument -ExcelDocument $Excel -FilePath $FilePath -OpenWorkBook
