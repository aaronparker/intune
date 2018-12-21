# Requires -Version 2
<#
    .SYNOPSIS
        Enable Windows 10 Storage Sense.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function Set-RegValue {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)] $Key,
        [Parameter(Mandatory = $True)] $Value,
        [Parameter(Mandatory = $True)] $Data,
        [Parameter(Mandatory = $True)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        $Type
    )
    try {
        If (!(Test-Path $Key)) {
            New-Item -Path $Key -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key with error $_."
        Break
    }
    finally {
        New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force
    }
}

$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:LocalAppData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile

# Ensure the StorageSense key exists
$key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense"


If (!(Test-Path "$key")) {
    New-Item -Path "$key" | Out-Null
}
If (!(Test-Path "$key\Parameters")) {
    New-Item -Path "$key\Parameters" | Out-Null
}
If (!(Test-Path "$key\Parameters\StoragePolicy")) {
    New-Item -Path "$key\Parameters\StoragePolicy" | Out-Null
}

# Set Storage Sense settings
# Enable Storage Sense
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1

# Set 'Run Storage Sense' to Every Week
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "2048" -Type DWord -Value 7

# Enable 'Delete temporary files that my apps aren't using'
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "04" -Type DWord -Value 1

# Set 'Delete files in my recycle bin if they have been there for over' to 60 days
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "08" -Type DWord -Value 1
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "256" -Type DWord -Value 60

# Set 'Delete files in my Downloads folder if they have been there for over' to 60 days
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "32" -Type DWord -Value 1
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "512" -Type DWord -Value 60

# Set value that Storage Sense has already notified the user
Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "StoragePoliciesNotified" -Type DWord -Value 1

Stop-Transcript
