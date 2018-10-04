# Requires -Version 2
<#
    .SYNOPSIS
        Enables OneDrive client update and configuration
        
    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function New-RegValue {
    Param (
        [Parameter(Mandatory = $True)]$Key,
        [Parameter(Mandatory = $True)]$Value,
        [Parameter(Mandatory = $True)]$Data,
        [Parameter(Mandatory = $True)][ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]$Type
    )
    If (!(Test-Path $Key)) { New-Item -Path $Key -Force }
    New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
}

$LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\OneDrive-UserConfig.log"
Start-Transcript -Path $LogFile

# Creates the EnableADAL registry value for silent account config
New-RegValue -Key "HKCU:\SOFTWARE\Microsoft\OneDrive" -Value "EnableADAL" -Data "1" -Type "Dword"


# Attempt to update OneDrive; Variables
$OneDrivePath = "$env:LocalAppData\Microsoft\OneDrive"
$OneDriveStandaloneUpdater = "OneDriveStandaloneUpdater.exe"
$OneDriveUpdater = Join-Path -Path $OneDrivePath -ChildPath $OneDriveStandaloneUpdater
$1709Version = [System.Version]"17.3.6816.0313"
$CurrentVersion = [System.Version]"18.151.0729.0012"

# Get current installed version
$folder = Get-ChildItem -Path $OneDrivePath | Where-Object { $_.Name -like "17.*" -or $_.Name -like "18.*" } `
    | Sort-Object -Descending | Select-Object -First 1

# If installed version is old, let's update it
# On first logon, need to wait for OneDrive to install
If ([System.Version]$folder.Name -le $1709Version) {
    For ($i = 1; $i -le 10; $i++) {
        If (Test-Path $OneDriveUpdater) { Break }
        Start-Sleep -Seconds 10
    }

    # Once installed, force the updater to run
    Start-Process -FilePath $OneDriveUpdater

    # Wait while the installer does its thing
    While ([System.Version]$folder.Name -le $CurrentVersion) {
        Start-Sleep -Seconds 10
        $folder = Get-ChildItem -Path $OneDrivePath | Where-Object { $_.Name -like "18.*" } `
            | Sort-Object -Descending | Select-Object -First 1
        If ([System.Version]$folder.Name -ge $CurrentVersion) { Break }
    }
}

<#
# If update hasn't worked, try download and install latest OneDrive update
$OneDriveRegistry = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "Version"
If ([System.Version]$OneDriveRegistry.Version -lt [System.Version]$CurrentVersion) {
    $OneDriveUrl = "https://go.microsoft.com/fwlink/?linkid=844652"
    $OneDriveInstaller = "$env:Temp\OneDriveSetup.exe"
    
    Invoke-WebRequest -Uri $OneDriveUrl -OutFile $OneDriveInstaller
    If (Test-Path $OneDriveInstaller) {
        Start-Sleep -Seconds 5
        Start-Process -FilePath $OneDriveInstaller -ArgumentList "/silent" -Wait
        Start-Sleep -Seconds 5
    }
    Else {
        Write-Error -Message "OneDrive setup failed to download."
    }
}
#>

Stop-Transcript
