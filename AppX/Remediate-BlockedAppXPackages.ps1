<#
        .SYNOPSIS
            Removes a specified list of AppX packages from the current system.

        .NOTES
 	        NAME: Remove-AppxApps.ps1
	        VERSION: 3.0
	        AUTHOR: Aaron Parker
	        TWITTER: @stealthpuppy

        .LINK
            https://stealthpuppy.com
#>
[System.String[]] $BlockList = (
    "MicrosoftTeams_8wekyb3d8bbwe", # Microsoft Teams package on Windows 11
    "Microsoft.XboxApp_8wekyb3d8bbwe", # Xbox Console Companion
    "Microsoft.BingNews_8wekyb3d8bbwe", # Microsoft News
    "Microsoft.GamingApp_8wekyb3d8bbwe", # Microsoft Xbox app?
    "Clipchamp.Clipchamp_yxz26nhyzhsrt" # Clipchamp on Windows 11
)

# Get elevated status. If elevated we'll remove packages from all users and provisioned packages
if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage") {
    [System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
else {
    try {
        $Elevated = $True
        "Test" | Out-File -FilePath "$env:SystemRoot\Test.txt" -ErrorAction "SilentlyContinue"
        Remove-Item -Path "$env:SystemRoot\Test.txt" -ErrorAction "SilentlyContinue"
    }
    catch {
        $Elevated = $False
    }
}

# Get the AppX package object by passing the string to the left of the underscore
# to Get-AppxPackage and passing the resulting package object to Remove-AppxPackage
if ($Elevated) {
    $Packages = Get-AppxPackage -AllUsers | Where-Object { $_.PackageFamilyName -in $BlockList }
    try {
        $Status = 0
        $Packages | Remove-AppxPackage -ErrorAction "SilentlyContinue"
    }
    catch [System.Exception] {
        Write-Output $_.Exception.Message
        $Status = 1
    }
    $Packages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in ($BlockList -split "_") }
    foreach ($Package in $Packages) {
        try {
            $Status = 0
            Remove-AppxProvisionedPackage -Online -PackageName $Package.PackageName -ErrorAction "SilentlyContinue"
        }
        catch [System.Exception] {
            Write-Output $_.Exception.Message
            $Status = 1
        }
    }
}
else {
    $Packages = Get-AppxPackage | Where-Object { $_.PackageFamilyName -in $BlockList }
    try {
        $Status = 0
        $Packages | Remove-AppxPackage -ErrorAction "SilentlyContinue"
    }
    catch [System.Exception] {
        Write-Output $_.Exception.Message
        $Status = 1
    }
}

return $Status
