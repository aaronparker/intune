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

function Set-Registry ($Item) {
    try {
        if (!(Test-Path -Path $Item.path -ErrorAction "SilentlyContinue")) {
            $params = @{
                Path        = $Item.path
                Type        = "RegistryKey"
                Force       = $True
                ErrorAction = "SilentlyContinue"
            }
            $ItemResult = New-Item @params
            if ("Handle" -in ($ItemResult | Get-Member | Select-Object -ExpandProperty "Name")) { $ItemResult.Handle.Close() }
        }
        $params = @{
            Path        = $Item.path
            Name        = $Item.name
            Value       = $Item.value
            Type        = $Item.type
            Force       = $True
            ErrorAction = "SilentlyContinue"
        }
        Set-ItemProperty @params > $Null
        $Result = 0
    }
    catch {
        $Result = 1
    }
    Write-Output -InputObject $Result
}

foreach ($Setting in $Settings) {
    Write-Output -InputObject $Setting.path
    return (Set-Registry -Item $Setting)
}
