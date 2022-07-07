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
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
Param (
    [Parameter(ValueFromPipeline, Mandatory = $False, Position = 0, HelpMessage = "Path to the CSV document describing the Dynamic Groups.")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
            if ( -not (Test-Path -Path $_)) {
                throw "$_ does not exist."
            }
            if (-Not ($_ | Test-Path -PathType Leaf) ) {
                throw "The Path argument must be a file. Folder paths are not allowed."
            }
            if ($_ -notmatch "(\.csv)") {
                throw "The file specified in the path argument must be either of type CSV."
            }

            return $True
        })]
    [System.IO.FileInfo] $Path = (Join-Path $pwd "AzureADDynamicGroups.csv")
)

begin {}
process {

    # Import CSV
    $csvGroups = Import-Csv $Path -ErrorAction SilentlyContinue

    # Get the existing dynamic groups from Azure AD
    try {
        $existingGroups = Get-AzureADMSGroup -All:$True | Where-Object { $_.GroupTypes -eq "DynamicMembership" } `
            -ErrorAction SilentlyContinue
    }
    catch {
        throw $_
    }
    finally {
        if ($existingGroups) { Write-Verbose -Message "Found existing dynamic groups." }
    }

    # Step through each group from the CSV file
    $output = @()
    foreach ($group in $csvGroups) {

        # Match any existing group with the same membership rule
        $matchingGroup = $existingGroups | Where-Object { $_.MembershipRule -eq $group.MembershipRule }
        if ($matchingGroup) {
            Write-Warning -Message "Skipping import - Membership rule for $($group.DisplayName) matches existing group $($matchingGroup.DisplayName)."

            # if the description needs updating on the group, update to match that listed in the CSV file
            if ($matchingGroup.Description -ne $group.Description) {
                try {
                    $setGrpParams = @{
                        Id          = ($matchingGroup.Id)
                        Description = $group.Description
                        ErrorAction = "SilentlyContinue"
                    }
                    if ($PSCmdlet.ShouldProcess($group.DisplayName , "Add description: [$($group.Description)].")) {
                        Set-AzureADMSGroup @setGrpParams
                        Write-Verbose -Message "Updated description on group: $($matchingGroup.DisplayName) to '$($group.Description)'"
                    }
                }
                catch {
                    Write-Warning -Message "Failed to update description on group: $($matchingGroup.DisplayName) to '$($group.Description)'"
                    throw $_
                }
            }
        }
        else {
            try {
                # Create the new group
                $newGrpParams = @{
                    DisplayName                   = $group.DisplayName
                    Description                   = $group.Description
                    GroupTypes                    = "DynamicMembership"
                    MembershipRule                = $group.MembershipRule
                    MembershipRuleProcessingState = "On"
                    SecurityEnabled               = $True
                    MailEnabled                   = $False
                    MailNickname                  = (New-Guid)
                    ErrorAction                   = "SilentlyContinue"
                }
                if ($PSCmdlet.ShouldProcess($group.DisplayName , "Create group.")) {
                    $newGroup = New-AzureADMSGroup @newGrpParams
                    $output += $newGroup
                    Write-Verbose -Message "Created group $($group.DisplayName) with membership rule $($group.MembershipRule)."
                }
            }
            catch {
                Write-Error -Message "Failed to create group $($group.DisplayName) with membership rule $($group.MembershipRule)."
                throw $_
            }
        }
    }

    # Return the list of groups that were created
    Write-Output -InputObject $output
}
