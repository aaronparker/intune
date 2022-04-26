<#
    .SYNOPSIS
        Enable 'Local Security Authority (LSA) protection'
        Forces LSA to run as Protected Process Light (PPL).
#>
[CmdletBinding()]
param()

$Settings = @"
[
    {
        "path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa",
        "name": "RunAsPPL",
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
