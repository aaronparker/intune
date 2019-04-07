[CmdletBinding()]
Param ()

# Install requored modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
$modules = @('AzureADPreview',  'Microsoft.Graph.Intune', 'WindowsAutoPilotIntune')
ForEach ($module in $modules) {
    Install-Module -Name $module
    Import-Module -Name $module
}
