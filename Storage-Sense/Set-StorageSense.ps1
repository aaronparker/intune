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

Function Test-WindowsVersion {
    <#
        .SYNOPSIS
            Creates a registry value in a target key. Creates the target key if it does not exist.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)]
        [ValidateSet('17763', '17134', '16299', '15063', '14393', '10240')]
        [string] $Build = "17763",

        [Parameter(Mandatory = $False)]
        [ValidateSet('Higher', 'Lower', 'Match')]
        [string] $Test = "Higher"
    )

    $currentBuild = [Environment]::OSVersion.Version.Build
    Switch ($Test) {
        "Higher" {
            If ($currentBuild -gt $Build) { Write-Output $True } Else { Write-Output $False }
        }
        "Lower" {
            If ($currentBuild -lt $Build) { Write-Output $True } Else { Write-Output $False }
        }
        "Match" {
            If ($currentBuild -eq $Build) { Write-Output $True } Else { Write-Output $False }
        }
    }
}


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
    }
    Else {
        Write-Verbose "Write value failed."
        Write-Output $False
    }
}

#region Actions
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:LocalAppData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile

If (Test-WindowsVersion -Build "17134" -Test "Higher") {
    Write-Verbose "This version of Windows supports Storage Sense via OMA-URI custom settings. Exiting."
}
ELse {

    # Ensure the StorageSense key exists
    $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"

    # Set Storage Sense settings
    # Enable Storage Sense
    Set-RegistryValue -Key $key -Value "01" -Type DWord -Data 1 -Verbose

    # Set 'Run Storage Sense' to Every Week
    Set-RegistryValue -Key $key -Value "2048" -Type DWord -Data 7 -Verbose

    # Enable 'Delete temporary files that my apps aren't using'
    Set-RegistryValue -Key $key -Value "04" -Type DWord -Data 1 -Verbose

    # Set 'Delete files in my recycle bin if they have been there for over' to 60 days
    Set-RegistryValue -Key $key -Value "08" -Type DWord -Data 1 -Verbose
    Set-RegistryValue -Key $key -Value "256" -Type DWord -Data 60 -Verbose

    # Set 'Delete files in my Downloads folder if they have been there for over' to 60 days
    Set-RegistryValue -Key $key -Value "32" -Type DWord -Data 1 -Verbose
    Set-RegistryValue -Key $key -Value "512" -Type DWord -Data 60 -Verbose

    # Set value that Storage Sense has already notified the user
    Set-RegistryValue -Key $key -Value "StoragePoliciesNotified" -Type DWord -Data 1 -Verbose
}

Stop-Transcript
#endregion
