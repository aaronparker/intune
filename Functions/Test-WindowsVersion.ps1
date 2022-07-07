Function Test-WindowsVersion {
    <#
        .SYNOPSIS
            Creates a registry value in a target key. Creates the target key if it does not exist.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)]
        [ValidateSet('17763', '17134', '16299', '15063', '14393', '10240')]
        [System.String] $Build = "17763",

        [Parameter(Mandatory = $False)]
        [ValidateSet('Higher', 'Lower', 'Match')]
        [System.String] $Test = "Higher"
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
