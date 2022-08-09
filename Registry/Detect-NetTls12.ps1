<#
    .SYNOPSIS
    Get registry keys
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
    try {
        $Value = Get-ItemProperty -Path $Key.Key -Name $Key.Value -ErrorAction "SilentlyContinue"
    }
    catch {
        $Value = $Null
    }

    if ($Null -ne $Value) {
        if ($Value.($Key.Value) -eq $Key.Data) {
            $Output += "`nValue match: $($Key.Key)\$($Key.Value)"
            $Result = 0
        }
        else {
            $Output += "`nNo value match: $($Key.Key)\$($Key.Value)"
            $Result = 1
        }
    }
    else {
        $Output += "`nNo value exists: $($Key.Key)\$($Key.Value)"
        $Result = 1
    }
}

Write-Host $Output
exit $Result
