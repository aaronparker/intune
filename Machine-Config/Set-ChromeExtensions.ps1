
# Chrome extensions
New-Item -Path 'HKLM:\Software\Policies\Google\Chrome' -Name ExtensionInstallForcelist -Force
$regKey = 'HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist'
Set-ItemProperty -path $regKey -name 1 -value 'bkbeeeffjjeopflfhgeknacdieedcoml;https://clients2.google.com/service/update2/crx'
Set-ItemProperty -path $regKey -name 2 -value 'ggjhpefgjjfobnfoldnjipclpcfbgbhl;https://clients2.google.com/service/update2/crx'
