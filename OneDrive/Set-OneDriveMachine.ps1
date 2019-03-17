# Requires -Version 2
<#
    .SYNOPSIS
        Configures the local machine with various tasks / features.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>

Function Set-RegistryValue {
    <#
        .SYNOPSIS
            Creates a registry value in a target key. Creates the target key if it does not exist.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string] $Key,

        [Parameter(Mandatory = $True)]
        [string] $Value,

        [Parameter(Mandatory = $True)]
        $Data,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        [string] $Type = "String"
    )

    try {
        If (Test-Path -Path $Key -ErrorAction SilentlyContinue) {
            Write-Verbose "Path exists: $Key"
        }
        Else {
            Write-Verbose -Message "Does not exist: $Key."

            $folders = $Key -split "\\"
            $parent = $folders[0]
            Write-Verbose -Message "Parent is: $parent."

            ForEach ($folder in ($folders | Where-Object { $_ -notlike "*:"})) {
                New-Item -Path $parent -Name $folder -ErrorAction SilentlyContinue | Out-Null
                $parent = "$parent\$folder"
                If (Test-Path -Path $parent -ErrorAction SilentlyContinue) {
                    Write-Verbose -Message "Created $parent."
                }
            }
            Test-Path -Path $Key -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key."
        Break
    }
    finally {
        Write-Verbose -Message "Setting $Value in $Key."
        New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $val = Get-Item -Path $Key
    If ($val.Property -contains $Value) {
        Write-Verbose "Write value success: $Value"
        Write-Output $True
    } Else {
        Write-Verbose "Write value failed."
        Write-Output $False
    }
}

#region Actions
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# Creates the SilentAccountConfig registry value for silent account config
# Creates the FilesOnDemandEnabled registry value to enabled Files On Demand for Windows 10 1709 and later
Set-RegistryValue -Key "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Value "SilentAccountConfig" -Data "1" -Type "Dword" -Verbose
Set-RegistryValue -Key "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Value "FilesOnDemandEnabled" -Data "1" -Type "Dword" -Verbose

# Ensure OneDrive is not disabled
Set-RegistryValue -Key "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Value "DisableFileSyncNGSC" -Data 0 -Type Dword -Verbose

Stop-Transcript
#region
