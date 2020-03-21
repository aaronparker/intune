Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ProgressPreference = "SilentlyContinue"

# Trust the PSGallery for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the script
Find-Script -Name "Get-AutopilotESPStatus" -Repository PSGallery | Install-Script -Force
Find-Module -Name "Microsoft.Graph.Intune" -Repository PSGallery | Install-Module "Microsoft.Graph.Intune" -AllowClobber
Get-AutopilotESPStatus -Online
