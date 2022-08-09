<#
    .SYNOPSIS
    Set registry keys
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Proactive remediations consumes host output.")]
param ()

#region Restart if running in a 32-bit session
If (!([System.Environment]::Is64BitProcess)) {
    If ([System.Environment]::Is64BitOperatingSystem) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Write-Verbose -Message "Restarting in 64-bit PowerShell."
        Write-Verbose -Message "FilePath: $ProcessPath."
        Write-Verbose -Message "Arguments: $Arguments."
        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $True
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        Exit 0
    }
}
#endregion

#region Functions
function Set-RegistryValue {
    <#
        .SYNOPSIS
            Creates a registry value in a target key. Creates the target key if it does not exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $True)]
        [System.String] $Key,

        [Parameter(Mandatory = $True)]
        [System.String] $Value,

        [Parameter(Mandatory = $True)]
        $Data,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        [System.String] $Type = "String"
    )

    try {
        $Result = $True
        if (Test-Path -Path $Key) {
        }
        else {
            New-Item -Path $Key -Force -ErrorAction "SilentlyContinue" | Out-Null
        }
        New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force -ErrorAction "SilentlyContinue" | Out-Null
    }
    catch {
        $Result = $False
        throw $_.Exception.Message
    }
    finally {
        Write-Output $Result
    }
}
#endregion

# TLS keys
$Keys = @"
[
    {
        "Key": "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319",
        "Value": "SystemDefaultTlsVersions",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\.NETFramework\\v4.0.30319",
        "Value": "SchUseStrongCrypto",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319",
        "Value": "SystemDefaultTlsVersions",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319",
        "Value": "SchUseStrongCrypto",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server",
        "Value": "Enabled",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server",
        "Value": "DisabledByDefault",
        "Data": 0,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client",
        "Value": "Enabled",
        "Data": 1,
        "Type": "DWord"
    },
    {
        "Key": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client",
        "Value": "DisabledByDefault",
        "Data": 0,
        "Type": "DWord"
    }
]
"@

$Output = "Results:"
foreach ($Key in ($Keys | ConvertFrom-Json)) {
    $Result = Set-RegistryValue -Key $Key.Key -Value $Key.Value -Data $Key.Data -Type $Key.Type
    if ($Result -eq $False) {
        $Output += "`nFailed to set: $($Key.Key)\$($Key.Value)"
        $Result = 1
    }
    else {
        $Output += "`nSuccessfully set: $($Key.Key)\$($Key.Value)"
        $Result = 0
    }
}
Write-Host $Output
exit $Result
