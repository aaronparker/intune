<#
    .SYNOPSIS
        Get locale settings for the system.
        Use with Proactive Remediations or PowerShell scripts
 
    .NOTES
 	    NAME: Detect-SystemLocale.ps1
	    VERSION: 1.0
	    AUTHOR: Aaron Parker
	    TWITTER: @stealthpuppy
 
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
Param (
    [System.String] $Locale = "en-AU"
)
    
# Select the locale
Switch ($Locale) {
    "en-US" {
        # United States
        $GeoId = 244
        $Timezone = "Pacific Standard Time"
    }
    "en-GB" {
        # Great Britain
        $GeoId = 242
        $Timezone = "GMT Standard Time"
    }
    "en-AU" {
        # Australia
        $GeoId = 12
        $Timezone = "AUS Eastern Standard Time"
    }
    Default {
        # Australia
        $GeoId = 12
        $Timezone = "AUS Eastern Standard Time"
    }
}
     
# Test regional settings
try {
    # Get regional settings
    Import-Module -Name "International"

    # System locale
    If ($Null -eq (Get-WinSystemLocale | Where-Object { $_.Name -eq $Locale })) {
        Write-Host "System locale does not match $Locale."
        Exit 1
    }

    # Language list
    If ($Null -eq (Get-WinUserLanguageList | Where-Object { $_.LanguageTag -eq $Locale })) {
        Write-Host "Language list does not match $Locale."
        Exit 1
    }

    # Home location
    If ($Null -eq (Get-WinHomeLocation | Where-Object { $_.GeoId -eq $GeoId })) {
        Write-Host "Home location does not match $Locale."
        Exit 1
    }

    # Time zone
    If ($Null -eq (Get-TimeZone | Where-Object { $_.Id -eq $Timezone })) {
        Write-Host "Time zone does not match $Timezone."
        Exit 1
    }

    # All settings are good exit cleanly
    Write-Host "All regional settings match $Locale and $Timezone."
    Exit 0
}
catch {
    Write-Host $_.Exception.Message
    Exit 1
}
