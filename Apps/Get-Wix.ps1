# Get latest version and download latest Wix release via GitHub API

# GitHub API to query for Greenshot repository
$repo = "wixtoolset/wix3"
$releases = "https://api.github.com/repos/$repo/releases"

# Query the Wix repository for releases, keeping the latest release
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$r = Invoke-WebRequest -Uri $releases -UseBasicParsing
$latestRelease = ($r.Content | ConvertFrom-Json | Where-Object { $_.prerelease -eq $False })[0]

# Array of releases and downloaded
$releases = $latestRelease.assets | Where-Object { $_.browser_download_url -match [regex]".*.exe$" } | `
    Select-Object name, browser_download_url
$obj = New-Object -TypeName PSObject
$obj | Add-Member -MemberType NoteProperty -Name "Version" -Value $latestRelease.tag_name
$obj | Add-Member -MemberType NoteProperty -Name "URI" -Value $releases.browser_download_url
Write-Output $obj

# Download the latest release
Invoke-WebRequest -Uri $obj.URI -OutFile $(Join-Path $PWD (Split-Path -Path $obj.URI -Leaf))

If (Get-WindowsOptionalFeature -Online -FeatureName NetFx3 | Where-Object { $_.State -ne "Enabled" }) {
    $result = Enable-WindowsOptionalFeature -Online -FeatureName NetFx3
    If ($result.RestartNeeded -eq $True) { Write-Warning ".NET Framework 3.5 installed. Restart needed." }
}

Invoke-Command -FilePath $(Join-Path $PWD (Split-Path -Path $obj.URI -Leaf)) -ArgumentList "-passive -norestart"
