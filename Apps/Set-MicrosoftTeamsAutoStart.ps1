<# 
    .DESCRIPTION 
        Prevent Microsoft Teams autostart.
#>
[CmdletBinding()]
Param (
    [Parameter()] $Path = "${env:ProgramFiles(x86)}\Teams Installer",
    [Parameter()] $File = "setup.json",
    [Parameter()] $VerbosePreference = "Continue"
)

$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

#region Functions
Function Set-JsonFile {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline)] $InputObject,
        [Parameter(Position = 1)] $Path
    )

    # Write JSON back to the file
    try {
        
        $InputObject | ConvertTo-Json | Set-Content -Path $Path -Force
        $Result = $True
    }
    catch {
        Throw "Failed to convert back to JSON and write file contents to [$Path]."
        $Result = $True
    }
    Write-Output -InputObject $Result
}

Function Set-JsonConfig {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline)] $InputObject
    )

    # Update Autostart value
    try {
        $InputObject.noAutoStart = $true
    }
    catch {
        Throw "Failed to set noAutoStart value"
    }
    Write-Output -InputObject $InputObject
}

Function Get-JsonConfig {
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline)] $Path
    )

    # Read the file and convert from JSON
    try {
        $Json = Get-Content -Path $Path | ConvertFrom-Json
    }
    catch {
        Throw "Failed to convert contents of [$Path] to JSON."
        Break
    }
    Write-Output -InputObject $Json
}

Function New-JsonConfig {
    $PSObject = [PSCustomObject] @{
        noAutoStart = $True
    }
    Write-Output -InputObject $PSObject
}
#endregion

# Set value in the JSON file
$Target = Join-Path -Path $Path -ChildPath $File
If (Test-Path -Path $Path) {
    If (Test-Path -Path $Target) {
        Get-JsonConfig -Path $Target | Set-JsonConfig | Set-JsonFile -Path $Target
    }
    Else {
        New-JsonConfig | Set-JsonFile -Path $Target
    }
}
Else {
    New-Item -Path $Path -ItemType "Directory" -Force
    New-JsonConfig | Set-JsonFile -Path $Target
}

# Stop the log file
Stop-Transcript
