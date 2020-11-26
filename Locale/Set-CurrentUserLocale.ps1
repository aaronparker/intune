<#
    .SYNOPSIS
        Set locale settings for the current user.
        Use with PowerShell scripts
 
    .NOTES
 	    NAME: Set-CurrentUserLocale.ps1
	    VERSION: 1.0
	    AUTHOR: Aaron Parker
	    TWITTER: @stealthpuppy
 
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding()]
Param (
    [System.String] $Locale = "en-AU",
    [System.String] $Path = "$env:Temp"
)
    
# Select the locale
Switch ($Locale) {
    "en-US" {
        # United States
        $GeoId = 244
        $Timezone = "Pacific Standard Time"
        $LanguageId = "0409:00000409"
    }
    "en-GB" {
        # Great Britain
        $GeoId = 242
        $Timezone = "GMT Standard Time"
        $LanguageId = "0809:00000809"
    }
    "en-AU" {
        # Australia
        $GeoId = 12
        $Timezone = "AUS Eastern Standard Time"
        $LanguageId = "0c09:00000409"
    }
    Default {
        # Australia
        $GeoId = 12
        $Timezone = "AUS Eastern Standard Time"  #"Cen. Australia Standard Time"
        $LanguageId = "0c09:00000409"
    }
}
    
#region #region XML
$languageXml = @"
    <gs:GlobalizationServices 
        xmlns:gs="urn:longhornGlobalizationUnattend">
        <!--User List-->
        <gs:UserList>
            <gs:User UserID="Current" CopySettingsToDefaultUserAcct="false" CopySettingsToSystemAcct="false"/>
        </gs:UserList>
        <!-- user locale -->
        <gs:UserLocale>
            <gs:Locale Name="$Locale" SetAsCurrent="true"/>
        </gs:UserLocale>
        <!-- system locale -->
        <gs:SystemLocale Name="$Locale"/>
        <!-- GeoID -->
        <gs:LocationPreferences>
            <gs:GeoID Value="$GeoId"/>
        </gs:LocationPreferences>
        <gs:MUILanguagePreferences>
            <gs:MUILanguage Value="$Locale"/>
            <gs:MUIFallback Value="en-US"/>
        </gs:MUILanguagePreferences>
        <!-- input preferences -->
        <gs:InputPreferences>
            <gs:InputLanguageID Action="add" ID="$LanguageId" Default="true"/>
        </gs:InputPreferences>
    </gs:GlobalizationServices>
"@
#endregion
    
# Set regional settings
try {
    Import-Module -Name "International"
    Set-WinUserLanguageList -LanguageList $Locale -Force
    Set-WinHomeLocation -GeoId $GeoId
    Set-TimeZone -Id $Timezone
    Set-Culture -CultureInfo $Locale
}
catch {
    Write-Error -Message $_.Exception.Message
    Exit 1
}

try {
    If (!(Test-Path -Path $Path)) { New-Item -Path $Path -ItemType "Directory" }
    $OutFile = Join-Path -Path $Path -ChildPath "language.xml"
    Out-File -FilePath $OutFile -InputObject $languageXml -Encoding ascii
}
catch {
    Write-Error -Message $_.Exception.Message
    Exit 1
}
    
try {
    & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:$OutFile"
}
catch {
    Write-Error -Message $_.Exception.Message
    Exit 1
}

# All settings are good exit cleanly
Write-Host "Set regional settings to $Locale and $Timezone."
Exit 0
