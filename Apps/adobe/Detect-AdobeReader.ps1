<#
    .SYNOPSIS
        Disables the prompt "Make Adobe Acrobat my default PDF application."
#>
[CmdletBinding()]
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

function Get-Registry ($Item) {
    try {
        if (Test-Path -Path $Item.path -ErrorAction "SilentlyContinue") {
            $params = @{
                Path        = $Item.path
                Name        = $Item.name
                ErrorAction = "SilentlyContinue"
            }
            $Value = Get-ItemProperty @params
            if ($Value.($Item.name) -eq $Item.value) {
                $Result = 0
            }
            else {
                $Result = 1
            }
        }
        else {
            $Result = 1
        }
    }
    catch {
        $Result = 1
    }
    Write-Output -InputObject $Result
}

foreach ($Setting in $Settings) {
    Write-Output -InputObject $Setting.path
    return (Get-Registry -Item $Setting)
}
