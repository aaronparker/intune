Connect-AzureAD

$thumb = (New-SelfSignedCertificate -DnsName "logonscript.home.stealthpuppy.com" -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider").Thumbprint
$pwd = ""
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
Export-PfxCertificate -cert "Cert:\CurrentUser\My\$thumb" -FilePath "c:\temp\examplecert.pfx" -Password $pwd

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("C:\temp\examplecert.pfx", $pwd)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

$application = New-AzureADApplication -DisplayName "PowerShellLogonScript" -IdentifierUris "https://stealthpuppy.com/logonscript"
New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier "PowerShellLogonScript18" -Type AsymmetricX509Cert -Usage Verify -Value $keyValue

$sp = New-AzureADServicePrincipal -AppId $application.AppId
Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole | where-object {$_.DisplayName -eq "Directory Readers"}).Objectid -RefObjectId $sp.ObjectId

$tenant=Get-AzureADTenantDetail
Connect-AzureAD -TenantId $tenant.ObjectId -ApplicationId  $Application.AppId -CertificateThumbprint $thumb
