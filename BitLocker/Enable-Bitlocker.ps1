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
        Check whether BitLocker is enabled; Enable BitLocker on AAD Joined devices and store recovery info in Azure AD

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
$logFile = "$env:ProgramData\IntuneScriptLogs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile -NoClobber
$VerbosePreference = "Continue"

try {
    # Running as SYSTEM BitLocker may not implicitly load and running as SYSTEM the env variable is likely not set, so explicitly load it
    # Assumption here is that we are running in the 64-bit PowerShell host
    Import-Module -Name "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules\BitLocker"

    # --------------------------------------------------------------------------
    #  Let's dump the starting point
    # --------------------------------------------------------------------------
    Write-Verbose -Message "STARTING POINT:  Get-BitLockerVolume $OSDrive"

    # Evaluate the Volume Status to see what we need to do...
    $bdeProtect = Get-BitLockerVolume -MountPoint $OSDrive | Select-Object -Property "VolumeStatus", "KeyProtector"

    # Account for an uncrypted drive 
    if ($bdeProtect.VolumeStatus -eq "FullyDecrypted" -or $bdeProtect.KeyProtector.Count -lt 1) {
        
        # Enable Bitlocker using TPM
        Write-Verbose -Message "Enabling BitLocker due to FullyDecrypted status or KeyProtector count less than 1"
        Enable-BitLocker -MountPoint $OSDrive -TpmProtector -SkipHardwareTest -UsedSpaceOnly -ErrorAction "Continue"
        Enable-BitLocker -MountPoint $OSDrive -RecoveryPasswordProtector -SkipHardwareTest
    }  
    elseif ($bdeProtect.VolumeStatus -eq "FullyEncrypted" -or $bdeProtect.VolumeStatus -eq "UsedSpaceOnly") {
        
        # $bdeProtect.ProtectionStatus -eq "Off" - This catches the Wait State
        if ($bdeProtect.KeyProtector.Count -lt 2) {
            Write-Verbose -Message "Volume Status is encrypted, but BitLocker only has one key protector (TPM)"
            Write-Verbose -Message "Adding a RecoveryPasswordProtector"
            manage-bde -on $OSDrive -UsedSpaceOnly -rp
        }
        else {
            Write-Verbose -Message "BitLocker is in Wait state - running manage-bde -on -UsedSpaceOnly"
            manage-bde -on $OSDrive -UsedSpaceOnly
        }
    }
				
    # Check if we can use BackupToAAD-BitLockerKeyProtector commandlet
    if (Get-Command -Name "BackupToAAD-BitLockerKeyProtector" -ErrorAction "SilentlyContinue") {
        
        # BackupToAAD-BitLockerKeyProtector commandlet exists
        Write-Verbose -Message "Saving Key to AAD using BackupToAAD-BitLockerKeyProtector"
        $BLV = Get-BitLockerVolume -MountPoint $OSDrive | Select-Object *
        If ($Null -ne $BLV.KeyProtector) {
            BackupToAAD-BitLockerKeyProtector -MountPoint $OSDrive -KeyProtectorId $BLV.KeyProtector[1].KeyProtectorId
        }
        Else {
            Write-Error "'Get-BitLockerVolume' failed to retrieve drive encryption details for $OSDrive"
        }
    }
    else { 
        # BackupToAAD-BitLockerKeyProtector commandlet not available, using other mechanism
        Write-Verbose -Message "BackupToAAD-BitLockerKeyProtector not available"
        Write-Verbose -Message "Saving Key to AAD using Enterprise Registration API"
        
        # Get the AAD Machine Certificate
        $cert = Get-ChildItem -Path "Cert:\LocalMachine\My\" | Where-Object { $_.Issuer -match "CN=MS-Organization-Access" }

        # Obtain the AAD Device ID from the certificate
        $id = $cert.Subject.Replace("CN=", "")

        # Get the tenant name from the registry
        $tenant = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\$($id)").UserEmail.Split('@')[1]

        # Create the URL to post the data to based on the tenant and device information
        $url = "https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"

        # Generate the body to send to AAD containing the recovery information
        Write-Verbose -Message "Saving key protector to AAD for self-service recovery by manually posting it to:"
        Write-Verbose -Message "`t$url"
        
        # Get the BitLocker key information from WMI
        (Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | ForEach-Object {
            $key = $_
            $body = "{""key"":""$($key.RecoveryPassword)"",""kid"":""$($key.KeyProtectorId.replace('{','').Replace('}',''))"",""vol"":""OSV""}"
            Write-Verbose -Message "KeyProtectorId : $($key.KeyProtectorId) key: $($key.RecoveryPassword)"
				
            # Post the data to the URL and sign it with the AAD Machine Certificate
            $req = Invoke-WebRequest -Uri $url -Body $body -UseBasicParsing -Method "Post" -UseDefaultCredentials -Certificate $cert
            $req.RawContent
            Write-Verbose -Message " -- Key save web request sent to AAD - Self-Service Recovery should work"
        }
    }

    # In case we had to encrypt, turn it on for any enabled volume
    Get-BitLockerVolume | Resume-BitLocker

    # --------------------------------------------------------------------------
    #  Finish - Let's dump the ending point
    # --------------------------------------------------------------------------
    Write-Verbose -Message "ENDING POINT:  Get-BitLockerVolume $OSDrive"
    $bdeProtect = Get-BitLockerVolume $OSDrive 
} 
catch { 
    Write-Error "Error while setting up AAD BitLocker, make sure that you are AAD joined and are running the cmdlet as an admin: $_" 
}

Stop-Transcript
