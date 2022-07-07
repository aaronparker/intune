<#
    .SYNOPSIS
        Disables the prompt "Make Adobe Acrobat my default PDF application."
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Output required by Proactive Remediations.")]
param()

$Settings = @"
[
    {
        "path": "HKCU:\\SOFTWARE\\Adobe\\Acrobat Reader\\DC\\AVAlert\\cCheckbox",
        "name": "iAppDoNotTakePDFOwnershipAtLaunchWin10",
        "value": 1,
        "type": "Dword"
    },
    {
        "path": "HKLM:\\SOFTWARE\\Policies\\Adobe\\Acrobat Reader\\DC\\FeatureLockDown",
        "name": "bDisableJavaScript",
        "value": 1,
        "type": "Dword"
    },
    {
        "path": "HKCU:\\SOFTWARE\\Adobe\\Adobe Acrobat\\DC\\AVAlert\\cCheckbox",
        "name": "iAppDoNotTakePDFOwnershipAtLaunchWin10",
        "value": 1,
        "type": "Dword"
    },
    {
        "path": "HKLM:\\SOFTWARE\\Policies\\Adobe\\Adobe Acrobat\\DC\\FeatureLockDown",
        "name": "bDisableJavaScript",
        "value": 1,
        "type": "Dword"
    }
]
"@ | ConvertFrom-Json

[System.Int16] $Script = 0
[System.Int16] $Result = 0

foreach ($Setting in $Settings) {
    try {
        if (Test-Path -Path $Setting.path -ErrorAction "SilentlyContinue") {
            $params = @{
                Path        = $Setting.path
                Name        = $Setting.name
                ErrorAction = "SilentlyContinue"
            }
            $Value = Get-ItemProperty @params
            if ($Value.($Setting.name) -eq $Setting.value) {
                $Result = 0
            }
            else {
                $Result = 1
                $Script = 1
            }
        }
        else {
            $Result = 1
            $Script = 1
        }
    }
    catch {
        $Result = 1
    }
    Write-Host "$Result $($Setting.path)"
}
exit $Script
