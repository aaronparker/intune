
# Get the latest Intune PowerShell SDK
$latestRelease = (Invoke-Webrequest -uri https://api.github.com/repos/Microsoft/Intune-PowerShell-SDK/releases | ConvertFrom-Json)[0]

# Return the latest version tag
$latestVersion = $latestRelease.tag_name
Write-Output $latestVersion

# Array of releases and downloaded
$releases = $latestRelease.assets | Select-Object name, browser_download_url
Write-Output $releases

# Output paths 
$releaseZip = Join-Path $pwd $(Split-Path $releases.browser_download_url -Leaf)
$extractFolder = Join-Path $pwd Intune-SDK

# Download and extract the latest release
Invoke-WebRequest -Uri $releases.browser_download_url -OutFile $releaseZip
New-Item -Path $extractFolder -ItemType Directory
Expand-Archive -LiteralPath $releaseZip -DestinationPath $extractFolder

# Get the SDK releases from the extracted archive
$releases = Get-ChildItem -Path (Join-Path $extractFolder "Release") -Directory | Select FullName

# Find the module path 
If ($PSVersionTable.PSVersion -lt [Version]"6.0") {
    $moduleFolder = ($releases | Where-Object { $_.FullName -like "*net471" }).FullName
}
Else {
    $moduleFolder = ($releases | Where-Object { $_.FullName -like "*netstandard2.0" }).FullName
}

# Import the Intune PowerShell module
Import-Module $moduleFolder

# Connect to Intune Graph API
Connect-MSGraph
