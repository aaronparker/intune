# Citrix Receiver / Workspace app as a preference
$Path = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Google\Chrome\Extensions"
$Value = "update_url"
$Data = "https://clients2.google.com/service/update2/crx"
$Key = "$Path\haiffjcadagjlijoggckpgfnoeiflnem"
New-Item -Path $Key -ErrorAction SilentlyContinue
New-ItemProperty -Path $Key -Name $Value -Value $Data -Force -ErrorAction SilentlyContinue

# Citrix Receiver / Workspace app as a policy
$Key = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
$ExistingValues = (Get-Item -Path $Key).Property
$Value = [int]$ExistingValues[$ExistingValues.Count-1] + 1
$Data = "haiffjcadagjlijoggckpgfnoeiflnem;https://clients2.google.com/service/update2/crx"
New-Item -Path $Key -ErrorAction SilentlyContinue
New-ItemProperty -Path $Key -Name $Value -Value $Data -Force -ErrorAction SilentlyContinue