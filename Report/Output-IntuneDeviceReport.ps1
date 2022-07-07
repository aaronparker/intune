#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Intune
<#
    .SYNOPSIS
        Outputs configuration objects from an Intune tenant into an Excel workbook
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $FilePath = $(Join-Path (Resolve-Path $pwd) "Devices.xlsx")
)

# Install required modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -ErrorAction SilentlyContinue
If ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted" ) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
$modules = @('PSWriteExcel')
ForEach ($module in $modules) {
    Install-Module -Name $module -Scope CurrentUser
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
$ExcelWorkSheet = Add-ExcelWorkSheet -ExcelDocument $Excel -WorksheetName "Devices" -Suppress $False -Option 'Replace'
Add-ExcelWorksheetData -ExcelWorksheet $ExcelWorkSheet -DataTable $Devices -AutoFit -Suppress $True -FreezeTopRow -TableStyle Light9
Save-ExcelDocument -ExcelDocument $Excel -FilePath $FilePath -OpenWorkBook
