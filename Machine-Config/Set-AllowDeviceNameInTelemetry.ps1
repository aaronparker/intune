# Enable AllowDeviceNameInTelemetry for Windows 10 1803 devices. Currently unable to do this via CSP
# https://docs.microsoft.com/en-au/windows/deployment/update/windows-analytics-get-started

$LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\AllowDeviceNameInTelemetry.log"
Start-Transcript -Path $LogFile

$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
$name = "AllowDeviceNameInTelemetry"
$value = "1"
New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null

Stop-Transcript
