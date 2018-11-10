<#
.SYNOPSIS
    Pin an application to the start menu.

.DESCRIPTION
    This script will pin a specified application to the start menu of the current user.

.PARAMETER ApplicationName
    Name of the application that should be pinned.

.EXAMPLE
    .\Add-StartMenuTile.ps1 -ApplicationName "Command prompt"

.NOTES
    FileName:    Add-StartMenuTile.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2018-09-18
    Updated:     2018-09-18
    Url: https://github.com/SCConfigMgr/Windows/blob/master/Start%20Menu/Add-StartMenuTile.ps1

    Version history:
    1.0.0 - (2018-09-18) Script created

    # Oct 2018
    Updated to unpin applications
#>

# Functions
function Get-PinnedAppState {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Name of a pinned application.")]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName
    )
    $PinnedApp = ((New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items() | Where-Object { $_.Name -like $ApplicationName }).verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from Start' }
    if ($PinnedApp -ne $null) {
        return $true
    }
    else {
        return $false
    }
}

function Get-Application {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Name of an application.")]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName
    )
    # Get all applications
    $Applications = (New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items()  
    $Applications = $Applications | Sort-Object -Property Name -Unique

    # Construct a list object for all applications and add each item from the string array
    $ApplicationList = New-Object -TypeName System.Collections.ArrayList
    foreach ($Application in $Applications) {
        $ApplicationList.Add($Application.Name) | Out-Null
    }

    # Check to see if application name from parameter input is in the application list
    if ($ApplicationName -in $ApplicationList) {
        return $true
    }
    else {
        return $false
    }
}

Function Pin-StartMenuTile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Name of the application that should be pinned.")]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName
    )
    Process {
        # Set PowerShell variables
        $ErrorActionPreference = "Stop"

        # Check if the specified parameter input is valid
        $ValidApplication = Get-Application -ApplicationName $ApplicationName
        if ($ValidApplication -eq $true) {
            # Check if app is already pinned
            $PinnedState = Get-PinnedAppState -ApplicationName $ApplicationName
            if ($PinnedState -eq $false) {
                try {
                    # Attempt to pin the application
                    $InvokePin = ((New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items() | Where-Object { $_.Name -like $ApplicationName }).verbs() | Where-Object { $_.Name.replace('&', '') -match 'Pin to Start' } | ForEach-Object { $_.DoIt() }
                    Write-Verbose -Message "Successfully pinned application: $($ApplicationName)"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to pin application '$($ApplicationName)'. Error message: $($_.Exception.Message)"
                }
            }
            else {
                Write-Information -Message "Application '$($ApplicationName)' is already pinned to the Start menu"
            }
        }
    }
}

Function Unpin-StartMenuTile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Name of the application that should be unpinned.")]
        [ValidateNotNullOrEmpty()]
        [string]$ApplicationName
    )
    Process {
        # Set PowerShell variables
        $ErrorActionPreference = "Stop"

        # Check if the specified parameter input is valid
        $ValidApplication = Get-Application -ApplicationName $ApplicationName
        if ($ValidApplication -eq $true) {
            # Check if app is already pinned
            $PinnedState = Get-PinnedAppState -ApplicationName $ApplicationName
            if ($PinnedState -eq $true) {
                try {
                    # Attempt to pin the application
                    $InvokePin = ((New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items() | Where-Object { $_.Name -like $ApplicationName }).verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from Start' } | ForEach-Object { $_.DoIt() }
                    Write-Verbose -Message "Successfully unpinned application: $($ApplicationName)"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to unpin application '$($ApplicationName)'. Error message: $($_.Exception.Message)"
                }
            }
            else {
                Write-Information -Message "Application '$($ApplicationName)' is already unpinned from the Start menu"
            }
        }
    }
}

# Pin and Unpin applications
$stampDate = Get-Date
$LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\PinStartMenuTile-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

Unpin-StartMenuTile "Skype" -Verbose
Unpin-StartMenuTile "Xbox" -Verbose
Unpin-StartMenuTile "Microsoft Remote Desktop" -Verbose
Unpin-StartMenuTile "Network Speed Test" -Verbose
Unpin-StartMenuTile "Microsoft News" -Verbose
Unpin-StartMenuTile "My Office" -Verbose
Unpin-StartMenuTile "Microsoft Store" -Verbose

Pin-StartMenuTile "Company Portal" -Verbose
Pin-StartMenuTile "Microsoft Teams" -Verbose
Pin-StartMenuTile "Excel" -Verbose
Pin-StartMenuTile "Word" -Verbose
Pin-StartMenuTile "Outlook" -Verbose
Pin-StartMenuTile "PowerPoint" -Verbose

Stop-Transcript
