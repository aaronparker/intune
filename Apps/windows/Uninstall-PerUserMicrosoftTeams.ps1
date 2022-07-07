<#
.SYNOPSIS
    This script allows you to uninstall the Microsoft Teams app and remove Teams directory for a user.

.DESCRIPTION
    Use this script to clear the installed Microsoft Teams application. Run this PowerShell script for each user profile
    for which the Teams App was installed on a machine. After the PowerShell has executed on all user profiles, Teams can be redeployed.

.NOTES
    https://docs.microsoft.com/en-us/microsoftteams/scripts/powershell-script-teams-deployment-clean-up
#>

$TeamsPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Teams')
$TeamsUpdateExePath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Teams', 'Update.exe')

try {
    if (Test-Path -Path $TeamsUpdateExePath) {
        # Uninstall app
        $proc = Start-Process -FilePath $TeamsUpdateExePath -ArgumentList "-uninstall -s" -PassThru
        $proc.WaitForExit()
    }
    if (Test-Path -Path $TeamsPath) {
        Remove-Item -Path $TeamsPath -Recurse -Force
    }
}
catch {
    Write-Error -ErrorRecord $_
    exit /b 1
}
