#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Intune, PSWriteExcel, ImportExcel
<#
    .SYNOPSIS
        Outputs configuration objects from an Intune tenant into an Excel workbook

    .NOTES

#>
[CmdletBinding()]
Param (
    [Parameter()]
    [string] $FilePath = $(Join-Path (Resolve-Path $pwd) "IntuneConfiguration.xlsx")
)

# Generate Excel spreadsheet
# Import-Module PSWriteExcel -Force -Verbose
$Excel = New-ExcelDocument -Verbose

# Read Intune device configuration policies
$configs = Get-IntuneDeviceConfigurationPolicy

ForEach ($config in $configs) {

    # Convert the PSCustomObject to a hashtable 
    $params = @{}
    ForEach ($property in $config.PSObject.Properties.Name) {
        If ($Null -ne $config.$property) {
            $params[$property] = $config.$property
        }
    }

    # Generate HTML view
    # Out-HtmlView -Table $params -Title $params.DisplayName

    $table = $params.GetEnumerator() | Sort Name | Select Name, Value

    $ExcelWorkSheet = Add-ExcelWorkSheet -ExcelDocument $Excel -WorksheetName $params.displayName -Supress $False -Option 'Replace'
    Add-ExcelWorksheetData -ExcelWorksheet $ExcelWorkSheet -DataTable $table -AutoFit -Supress $True -FreezeTopRow -TableStyle Light9
}

Save-ExcelDocument -ExcelDocument $Excel -FilePath $FilePath -OpenWorkBook
