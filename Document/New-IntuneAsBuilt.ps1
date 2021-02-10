[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $Path = $PWD,

    [Parameter(Mandatory = $False)]
    [System.String] $Company = "Insentra"
)

# Get elevation status
[System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

If ($Elevated) {
    # Make Invoke-WebRequest faster
    $ProgressPreference = "SilentlyContinue"

    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Host "Trusting the repository: PSGallery" -ForegroundColor Cyan
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    # Install the modules
    Find-Module -Name IntuneDocumentation, Microsoft.Graph.Intune, PSWord -Repository PSGallery | Install-Module -AllowClobber -Scope AllUsers
}
Else {
    Write-Host "Not running elevated. Check modules are installed." -ForegroundColor Cyan
    Find-Module -Name IntuneDocumentation, Microsoft.Graph.Intune, PSWord -Repository PSGallery | Install-Module -AllowClobber -Scope CurrentUser
}

# Import modules
Import-Module IntuneDocumentation, Microsoft.Graph.Intune, PSWord -Force

# Create the Intune as-built
$params = @{
    FullDocumentationPath = (Join-Path -Path $Path -ChildPath "$Company-IntuneAsBuilt.docx")
    UseTranslationBeta = $True
}
Invoke-IntuneDocumentation @params
