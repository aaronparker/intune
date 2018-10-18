# Install required modules
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
If (!(Get-PackageProvider | Where-Object { $_.Name -eq "NuGet" })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force
}
If ((Get-PSRepository -Name PSGallery).InstallationPolicy -eq "Untrusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
Install-Module -Name AzureAD -Scope CurrentUser
Import-Module -Name AzureAD
Install-Module -Name ADAL.PS -Scope CurrentUser
Import-Module -Name ADAL.PS

# Find tenant details
$cert = Get-ChildItem "Cert:\LocalMachine\My\" | Where-Object { $_.Issuer -match "CN=MS-Organization-Access" }
$id = $cert.Subject.Replace("CN=", "")
$objUser = New-Object System.Security.Principal.NTAccount($env:USERNAME)
$strSID = ($objUser.Translate([System.Security.Principal.SecurityIdentifier])).Value
$basePath = "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$strSID\IdentityCache\$strSID"
$userId = (Get-ItemProperty -Path $basePath -Name UserName).UserName
If ($userId -and $userId -like "*@*") {
    $tenant = ($userId).ToLower().Split('@')[1]
}

Function Get-AuthToken {
    param(
        [Parameter(Mandatory = $true)] $TenantName,
        [Parameter(Mandatory = $true)] $ClientId
    )

    # $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $redirectUri = "https://home.stealthpuppy.com/logonscript"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$TenantName"
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $promptBehaviour = [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto
    $authParam = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList $promptBehaviour
    $authenticationTask = $authContext.AcquireTokenASync($resourceAppIdURI, $clientId, $redirectUri, $authParam)
    Write-Output $authenticationTask
}
Get-AuthToken -TenantName $tenant -ClientId "8cc48d52-05b3-48c0-992e-7038c1eca1cd"
