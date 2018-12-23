#Requires -Version 2
#Requires -Modules AzureADPreview
<#
    .SYNOPSIS
        Creates Azure AD dynamic groups from definitions listed in an external CSV file.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
[CmdletBinding()]
Param (
    [Parameter(ValueFromPipeline, Mandatory = $False, Position = 0, HelpMessage = "Path to the CSV document describing the Dynamic Groups.")]
    [ValidateScript( {
            If ( -Not (Test-Path -Path $_)) {
                Throw "$_ does not exist."
            }
            If (-Not ($_ | Test-Path -PathType Leaf) ) {
                Throw "The Path argument must be a file. Folder paths are not allowed."
            }
            If ($_ -notmatch "(\.csv)") {
                Throw "The file specified in the path argument must be either of type CSV."
            }
            
            Return $True
        })]
    [System.IO.FileInfo] $Path = (Join-Path $pwd "DynamicGroups.csv")
)

# Import CSV
$csvGroups = Import-Csv $Path -ErrorAction SilentlyContinue

try {
    $existingGroups = Get-AzureADMSGroup -All:$True | Where-Object { $_.GroupTypes -eq "DynamicMembership" } -ErrorAction SilentlyContinue `
        | Select-Object DisplayName, MembershipRule
}
catch {
    Throw $_
}
finally {
    Write-Verbose "Found existing dynamic groups."
}

ForEach ($group in $csvGroups) {
    $matchingGroup = $existingGroups | Where-Object { $_.MembershipRule -eq $group.MembershipRule }
    If ($matchingGroup) {
        Write-Verbose "Membership rule for $group.DisplayName matches existing group $matchingGroup.DisplayName. Skipping import."
    }
    Else {
        try {
            New-AzureADMSGroup -DisplayName $group.DisplayName -Description $group.Description -MembershipRule $group.MembershipRule `
                -SecurityEnabled $True -ErrorAction SilentlyContinue
        }
        catch {
            Throw $_
        }
    }
}
