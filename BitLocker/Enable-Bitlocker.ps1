<#PSScriptInfo 
    .VERSION 3.0
    .GUID f5187e3f-ed0a-4ce1-b438-d8f421619ca3 
    .ORIGINAL AUTHOR Jan Van Meirvenne 
    .MODIFIED BY Sooraj Rajagopalan, Paul Huijbregts & Pieter Wigleven, Sean McLaren, Imad Balute
    .COPYRIGHT 
    .TAGS Azure Intune BitLocker  
    .LICENSEURI  
    .PROJECTURI  
    .ICONURI  
    .EXTERNALMODULEDEPENDENCIES  
    .REQUIREDSCRIPTS  
    .EXTERNALSCRIPTDEPENDENCIES  
    .RELEASENOTES  
#>
<#
    .DESCRIPTION 
        Check whether BitLocker is Enabled, if not Enable Bitlocker on AAD Joined devices and store recovery info in AAD. 
        Store key in temp folder, just in case we need to use another task to copy it to OD4B

    .NOTES
        URL: https://blogs.technet.microsoft.com/showmewindows/2018/01/18/how-to-enable-bitlocker-and-escrow-the-keys-to-azure-ad-when-using-autopilot-for-standard-users/
        Updates with removing aliases, update paths, formatting
#> 
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $OSDrive = $env:SystemDrive
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Transcript for logging/troubleshooting
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile -NoClobber
$VerbosePreference = "Continue"

try {
    # Running as SYSTEM BitLocker may not implicitly load and running as SYSTEM the env variable is likely not set, so explicitly load it
    Import-Module -Name "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\BitLocker"
    # Import-Module -Name "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\Modules\BitLocker"

    # --------------------------------------------------------------------------
    #  Let's dump the starting point
    # --------------------------------------------------------------------------
    Write-Verbose -Message " STARTING POINT:  Get-BitLockerVolume $OSDrive"

    # Evaluate the Volume Status to see what we need to do...
    $bdeProtect = Get-BitLockerVolume -MountPoint $OSDrive | Select-Object -Property VolumeStatus, KeyProtector

    # Account for an uncrypted drive 
    if ($bdeProtect.VolumeStatus -eq "FullyDecrypted" -or $bdeProtect.KeyProtector.Count -lt 1) {
        Write-Verbose -Message " Enabling BitLocker due to FullyDecrypted status or KeyProtector count less than 1"
        # Enable Bitlocker using TPM
        Enable-BitLocker -MountPoint $OSDrive -TpmProtector -SkipHardwareTest -UsedSpaceOnly -ErrorAction Continue
        Enable-BitLocker -MountPoint $OSDrive -RecoveryPasswordProtector -SkipHardwareTest
    }  
    elseif ($bdeProtect.VolumeStatus -eq "FullyEncrypted" -or $bdeProtect.VolumeStatus -eq "UsedSpaceOnly") {
        # $bdeProtect.ProtectionStatus -eq "Off" - This catches the Wait State
        if ($bdeProtect.KeyProtector.Count -lt 2) {
            Write-Verbose -Message " Volume Status is encrypted, but BitLocker only has one key protector (TPM)"
            Write-Verbose -Message "  Adding a RecoveryPasswordProtector"
            manage-bde -on $OSDrive -UsedSpaceOnly -rp
        }
        else {
            Write-Verbose -Message " BitLocker is in Wait State - running manage-bde -on -UsedSpaceOnly"
            manage-bde -on $OSDrive -UsedSpaceOnly
        }
    }

    # Writing recovery key to temp directory, another user-mode task will move this to OneDrive for Business (if configured)
    # Write-Verbose -Message " Writing key protector to temp file so we can move it to OneDrive for Business"
    # (Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector | Out-File "$env:SystemRoot\Temp\$($env:computername)-BitlockerRecoveryPassword.txt"
				
    # Check if we can use BackupToAAD-BitLockerKeyProtector commandlet
    $cmdName = "BackupToAAD-BitLockerKeyProtector"
    if (Get-Command $cmdName -ErrorAction SilentlyContinue) {
        Write-Verbose -Message " Saving Key to AAD using BackupToAAD-BitLockerKeyProtector commandlet"
        # BackupToAAD-BitLockerKeyProtector commandlet exists
        $BLV = Get-BitLockerVolume -MountPoint $OSDrive | Select-Object *
        If ($Null -ne $BLV.KeyProtector) {
            BackupToAAD-BitLockerKeyProtector -MountPoint $OSDrive -KeyProtectorId $BLV.KeyProtector[1].KeyProtectorId
        }
        Else {
            Write-Error "'Get-BitLockerVolume' failed to retrieve drive encryption details for $OSDrive"
        }
    }
    else { 
        Write-Verbose -Message " Saving Key to AAD using Enterprise Registration API"
        # BackupToAAD-BitLockerKeyProtector commandlet not available, using other mechanism
        # Get the AAD Machine Certificate
        $cert = Get-ChildItem Cert:\LocalMachine\My\ | Where-Object { $_.Issuer -match "CN=MS-Organization-Access" }

        # Obtain the AAD Device ID from the certificate
        $id = $cert.Subject.Replace("CN=", "")

        # Get the tenant name from the registry
        $tenant = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\$($id)).UserEmail.Split('@')[1]

        # Generate the body to send to AAD containing the recovery information
        Write-Verbose -Message " COMMAND BackupToAAD-BitLockerKeyProtector failed!"
        Write-Verbose -Message " Saving key protector to AAD for self-service recovery by manually posting it to:"
        Write-Verbose -Message "                     https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"
				    # Get the BitLocker key information from WMI
        (Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | ForEach-Object {
            $key = $_
            Write-Verbose -Message "kid : $($key.KeyProtectorId) key: $($key.RecoveryPassword)"
            $body = "{""key"":""$($key.RecoveryPassword)"",""kid"":""$($key.KeyProtectorId.replace('{','').Replace('}',''))"",""vol"":""OSV""}"
				
            # Create the URL to post the data to based on the tenant and device information
            $url = "https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"
				
            # Post the data to the URL and sign it with the AAD Machine Certificate
            $req = Invoke-WebRequest -Uri $url -Body $body -UseBasicParsing -Method Post -UseDefaultCredentials -Certificate $cert
            $req.RawContent
            Write-Verbose -Message " -- Key save web request sent to AAD - Self-Service Recovery should work"
        }
    }

    # In case we had to encrypt, turn it on for any enabled volume
    Get-BitLockerVolume | Resume-BitLocker

    # --------------------------------------------------------------------------
    #  Finish - Let's dump the ending point
    # --------------------------------------------------------------------------
    Write-Verbose -Message " ENDING POINT:  Get-BitLockerVolume $OSDrive"
    $bdeProtect = Get-BitLockerVolume $OSDrive 
} 
catch { 
    Write-Error "Error while setting up AAD Bitlocker, make sure that you are AAD joined and are running the cmdlet as an admin: $_" 
}

Stop-Transcript
