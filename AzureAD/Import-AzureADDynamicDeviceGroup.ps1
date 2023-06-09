#Requires -Modules Microsoft.Graph
<#
    .SYNOPSIS
        Creates Azure AD dynamic security groups from definitions listed in an external CSV file.
        Requires external authentication to the tenant before executing the script.

        Authenticate to the target tenant with:

        $Scopes = "Group.ReadWrite.All", "Directory.ReadWrite.All"
        Connect-MgGraph -Scopes $Scopes

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param (
    [Parameter(ValueFromPipeline, Mandatory = $false, Position = 0, HelpMessage = "Path to the CSV document describing the Dynamic Groups.")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
            if ( -not (Test-Path -Path $_)) { throw "$_ does not exist." }
            if ( -not ($_ | Test-Path -PathType Leaf) ) { throw "The Path argument must be a file. Folder paths are not allowed." }
            if ($_ -notmatch "(\.csv)") { throw "The file specified in the path argument must be either of type CSV." }
            return $true
        })]
    [System.IO.FileInfo] $Path = (Join-Path -Path $PSScriptRoot -ChildPath "DynamicDeviceGroups.csv")
)

begin {}
process {

    # Import CSV
    $csvGroups = Import-Csv $Path -ErrorAction "Stop"

    # Get the existing dynamic groups from Azure AD
    $ExistingGroups = Get-MgGroup -All:$true | Where-Object { $_.GroupTypes -eq "DynamicMembership" } -ErrorAction "Stop"
    if ($ExistingGroups) { Write-Verbose -Message "Found $($ExistingGroups.Count) existing dynamic groups." }

    # Step through each group from the CSV file
    foreach ($group in $csvGroups) {

        # Match any existing group with the same display name membership rule. This means that we can run this against any tenant
        # Update to match against $_.Id if you want to ensure
        $matchingGroup = $ExistingGroups | Where-Object { $_.DisplayName -eq $group.DisplayName -and $_.MembershipRule -eq $group.MembershipRule }
        if ($matchingGroup) {
            Write-Warning -Message "Skipping import - Membership rule for $($group.DisplayName) matches existing group $($matchingGroup.DisplayName)."

            # if the description needs updating on the group, update to match that listed in the CSV file
            if ($matchingGroup.Description -ne $group.Description) {
                if ($PSCmdlet.ShouldProcess($group.DisplayName , "Update description: '$($group.Description)'.")) {
                    $params = @{
                        Id          = $matchingGroup.Id
                        Description = $group.Description
                        ErrorAction = "Stop"
                    }
                    Update-MgGroup @params
                }
            }
        }
        else {
            # Create the new group
            if ($PSCmdlet.ShouldProcess($group.DisplayName , "Create group.")) {
                Write-Verbose -Message "Created group '$($group.DisplayName)' with membership rule '$($group.MembershipRule)'."
                $params = @{
                    DisplayName                   = $group.DisplayName
                    Description                   = $group.Description
                    GroupTypes                    = "DynamicMembership"
                    MembershipRule                = $group.MembershipRule
                    MembershipRuleProcessingState = "On"
                    SecurityEnabled               = $true
                    MailEnabled                   = $false
                    MailNickname                  = (New-Guid)
                    ErrorAction                   = "Stop"
                }
                $newGroup = New-MgGroup @params
                Write-Output -InputObject $newGroup
            }
        }
    }
}
