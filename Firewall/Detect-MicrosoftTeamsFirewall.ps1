<#
    .SYNOPSIS
        Detect whether the Microsoft Teams firewall policies have been created

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy
#>

#region Functions
function Get-LoggedInUserProfile {
    $ComputerSystem = Get-CimInstance -Class "Win32_ComputerSystem"
    if ([System.String]::IsNullOrEmpty($ComputerSystem.UserName)) {
        throw "Cannot find UserName in Win32_ComputerSystem."
    }
    else {
        try {
            Get-CimInstance -Class "Win32_UserProfile" | `
                Where-Object { $_.SID -notin @("S-1-5-18", "S-1-5-19", "S-1-5-20") } | `
                Where-Object { $_.LocalPath -match $(($ComputerSystem.UserName -split "\\")[-1]) } | `
                Select-Object -ExpandProperty "LocalPath" | Write-Output
        }
        catch {
            throw "Cannot determine user profile for the logged in user."
        }
    }
}

function Get-MicrosoftTeamsFirewallRule {
    param (
        [Parameter(Mandatory = $True)]
        [System.String] $Path
    )
    $TeamsPath = Join-Path -Path $Path -ChildPath "AppData\Local\Microsoft\Teams\Current\Teams.exe"
    if (Test-Path -Path $TeamsPath) {
        $Rule = "Microsoft Teams: $TeamsPath"
        if (Get-NetFirewallRule -DisplayName $Rule -ErrorAction "SilentlyContinue") {
            return 0
        }
        else {
            return 1
        }
    }
    else {
        # Return success if Teams is not installed
        return 0
    }
}
#endregion Functions

$Profiles = Get-LoggedInUserProfile
foreach ($Item in $Profiles) {
    if ((Get-MicrosoftTeamsFirewallRule -Path $Item) -eq 1) {
        Write-Output -InputObject "Rule not detected for: $Item"
        exit 1
    }
}
Write-Output -InputObject "Firewall rules OK."
exit 0
