<#
    .SYNOPSIS
        Create the Microsoft Teams firewall policies have been created

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

function Set-MicrosoftTeamsFirewallRule {
    param (
        [Parameter(Mandatory = $True)]
        [System.String] $Path
    )
    $TeamsPath = Join-Path -Path $Path -ChildPath "AppData\Local\Microsoft\Teams\Current\Teams.exe"
    if (Test-Path -Path $TeamsPath) {
        if (Get-NetFirewallApplicationFilter -Program $TeamsPath -ErrorAction "SilentlyContinue") {
        } 
        else {
            try {
                $Rule = "Microsoft Teams: $TeamsPath"
                $params = @{
                    DisplayName = $Rule
                    Direction   = "Inbound"
                    Profile      = "Any" #"Domain", "Public", "Private"
                    Program     = $TeamsPath
                    Action      = "Allow"
                    Protocol    = "Any"
                }
                New-NetFirewallRule @params
            }
            catch {
                throw $_.Exception.Message
            }
        }
    } 
    else {
        throw "Cannot find path: $TeamsPath"
    }     
}
#endregion Functions


try {
    $Profiles = Get-LoggedInUserProfile
    foreach ($Item in $Profiles) {
        Set-MicrosoftTeamsFirewallRule -Path $Item
    }
} 
catch [Exception] {
    Write-Output -InputObject $_.Exception.Message
    exit 1
} 
finally {
    Write-Output -InputObject "Firewall rules created for Microsoft Teams."
    exit 0
}
