# https://docs.microsoft.com/en-us/microsoft-store/microsoft-store-for-business-education-powershell-module

# Install and import the module
Install-Module -Name MSStore
Import-Module -Name MSStore

# Connect to the Store
Grant-MSStoreClientAppAccess
Connect-MSStore

# Get the Store inventory
Get-MSStoreInventory


# View products assigned to people
Get-MSStoreSeatAssignments -ProductId 9NBLGGH4R2R6 -SkuId 0016

# Assign Product (Product ID and SKU ID combination) to a User (user@host.com)
Add-MSStoreSeatAssignments  -ProductId 9NBLGGH4R2R6 -SkuId 0016 -PathToCsv C:\People.csv  -ColumnName UserPrincipalName

# Reclaim a product (Product ID and SKU ID combination) from a User (user@host.com)
Remove-MSStoreSeatAssignments  -ProductId 9NBLGGH4R2R6 -SkuId 0016 -PathToCsv C:\People.csv -ColumnName UserPrincipalName


<#
PS C:\> Get-Command -Module MSStore

CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-MSStoreSeatAssignment                          1.0.0.1    MSStore
Function        Add-MSStoreSeatAssignments                         1.0.0.1    MSStore
Function        Connect-MSStore                                    1.0.0.1    MSStore
Function        Get-MSStoreInventory                               1.0.0.1    MSStore
Function        Get-MSStoreSeatAssignments                         1.0.0.1    MSStore
Function        Grant-MSStoreClientAppAccess                       1.0.0.1    MSStore
Function        Remove-MSStoreSeatAssignment                       1.0.0.1    MSStore
Function        Remove-MSStoreSeatAssignments                      1.0.0.1    MSStore
#>
