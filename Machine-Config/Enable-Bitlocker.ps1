# Requires -Version 4
<#
    .SYNOPSIS
        Ensure BitLocker is running on Windows 10 Azure AD joined machines and the recovery key is written to Azure AD.

    .NOTES
        Author: Jos Lieben
        Twitter: @joslieben

        Original Author / idea: Jan Van Meirvenne
        Additional credit: Pieter Wigleven
        Date: 14-06-2017
        Script home: http://www.lieben.nu
        Copyright: MIT

    .LINK
        http://www.lieben.nu/liebensraum/2017/06/automatically-BitLocker-windows-10-mdm-intune-azure-ad-joined-devices/
#>
$logFile = Join-Path $env:ProgramData -ChildPath "Intune-PowerShell-Logs\enableBitlocker.log"
$postKeyToAAD = $True
$ErrorActionPreference = "Stop"
$version = "0.04"
$scriptName = "enableBitlocker"
Add-Content -Path $logFile -Value "$(Get-Date): $scriptName $version  starting on $($env:computername)"

$key = 'HKLM:\SOFTWARE\Policies\Microsoft\FVE'
If (Test-Path -Path $key){
    Add-Content -Path $logFile -Value "$(Get-Date): $scriptName $version  removing $key"
    Remove-Item -Path $key -Force
}

try {
    $bitlockerStatus = Get-BitLockerVolume $env:SystemDrive -ErrorAction Stop | Select-Object -Property VolumeStatus
}
catch {
    Add-Content -Path $logFile -Value "Failed to retrieve BitLocker status of system drive $_"
    $postKeyToAAD = $False
    Throw "Failed to retrieve BitLocker Status of System Drive"
}

if ($bitlockerStatus.VolumeStatus -eq "FullyDecrypted") {
    Add-Content -Path $logFile -Value "$($env:SystemDrive) system volume not yet encrypted, ejecting media and attempting to encrypt"
    try {
        # Automatically unmount any iso/dvd's
        $diskmaster = New-Object -ComObject IMAPI2.MsftDiscMaster2 
        $diskRecorder = New-Object -ComObject IMAPI2.MsftDiscRecorder2 
        $diskRecorder.InitializeDiscRecorder($diskMaster) 
        $diskRecorder.EjectMedia() 
    }
    catch {
        Add-Content -Path $logFile -Value "Failed to unmount DVD $_"
    }

    try {
        # Automatically unmount any USB sticks
        $volumes = get-wmiobject -Class Win32_Volume | Where-Object {$_.drivetype -eq '2'}  
        foreach ($volume in $volumes) {
            $ejectCmd = New-Object -comObject Shell.Application
            $ejectCmd.NameSpace(17).ParseName($volume.driveletter).InvokeVerb("Eject")
        }
    }
    catch {
        Add-Content -Path $logFile -Value "Failed to unmount USB device $_"
    }

    try {
        #Enable BitLocker using TPM
        Enable-BitLocker -MountPoint $env:SystemDrive -UsedSpaceOnly -TpmProtector -ErrorAction Stop -SkipHardwareTest -Confirm:$False
        Add-Content -Path $logFile -Value "BitLocker enabled using TPM"
    }
    catch {
        Add-Content -Path $logFile -Value "Failed to enable BitLocker using TPM: $_"
        $postKeyToAAD = $False
        Throw "Error while setting up AAD BitLocker during TPM step: $_"
    }

    try {
        #Enable BitLocker with a normal password protector
        Enable-BitLocker -MountPoint $env:SystemDrive -UsedSpaceOnly -RecoveryPasswordProtector -ErrorAction Stop -SkipHardwareTest -Confirm:$False
        Add-Content -Path $logFile -Value "BitLocker recovery password set."
    }
    catch {
        if ($_.Exception -like "*0x8031004E*") {
            Add-Content -Path $logFile -Value "reboot required before BitLocker can be enabled."
        }
        else {
            Add-Content -Path $logFile -Value "Error while setting up AAD BitLocker: $_"
            $postKeyToAAD = $False
            Throw "Error while setting up AAD BitLocker during noTPM step: $_"
        }
    } 
}
else {
    Add-Content -Path $logFile -Value "System volume $($env:SystemDrive) already encrypted"
}

if ($postKeyToAAD) {
    Add-Content -Path $logFile -Value "Will attempt to update your recovery key in AAD"
    try {
        $cert = Get-ChildItem Cert:\LocalMachine\My\ | Where-Object { $_.Issuer -match "CN=MS-Organization-Access" }
        $id = $cert.Subject.Replace("CN=", "")
        Add-Content -Path $logFile "using certificate $id"
        
        $objUser = New-Object System.Security.Principal.NTAccount($env:USERNAME)
        $strSID = ($objUser.Translate([System.Security.Principal.SecurityIdentifier])).Value
        $basePath = "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$strSID\IdentityCache\$strSID"
        $userId = (Get-ItemProperty -Path $basePath -Name UserName).UserName
        if ($userId -and $userId -like "*@*") {
            $tenant = ($userId).ToLower().Split('@')[1]
        }
        Add-Content -Path $logFile -Value "detected tenant $tenant"

        try {
            # Set TLS v1.2
            $res = [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Add-Content -Path $logFile -Value "TLS set to v1.2"
        }
        catch {
            Add-Content -Path $logFile -Value "could not set TLS to v1.2"
        }
        (Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector| Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}| ForEach-Object {
            $key = $_
            Add-Content -Path $logFile -Value "kid : $($key.KeyProtectorId) key: $($key.RecoveryPassword)"
            $body = "{""key"":""$($key.RecoveryPassword)"",""kid"":""$($key.KeyProtectorId.replace('{','').Replace('}',''))"",""vol"":""OSV""}"
            $url = "https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"
            $req = Invoke-WebRequest -Uri $url -Body $body -UseBasicParsing -Method Post -UseDefaultCredentials -Certificate $cert
            Add-Content -Path $logFile -Value "Key updated in AAD"
        }
    }
    catch {
        Add-Content -Path $logFile -Value "Failed to update key in AAD: $_"
        Throw "Failed to update key in AAD: $_"
    }
}
