#Requires -PSEdition Desktop
#Requires -Version 5
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Detect whether the UE-V service is enabled

    .DESCRIPTION
        Detect whether the UE-V service is enabled and returns status code for Proactive Remediations

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com/user-experience-virtualzation-intune/

    .EXAMPLE
        Set-Uev.ps1
#>
[CmdletBinding(SupportsShouldProcess = $False, HelpURI = "https://github.com/aaronparker/intune/blob/main/Uev/README.md")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Output required by Proactive Remediations.")]
param ()

function Test-WindowsEnterprise {
    try {
        Import-Module -Name "Dism"
        $edition = Get-WindowsEdition -Online -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Error -Message "Failed to run Get-WindowsEdition. Defaulting to False."
    }
    if ($edition.Edition -eq "Enterprise") {
        return $True
    }
    else {
        return $False
    }
}
#endregion

# If running Windows 10/11 Enterprise
if (Test-WindowsEnterprise) {

    # If the UEV module is installed
    if (Get-Module -ListAvailable -Name "UEV") {

        # Detect the UE-V service
        Import-Module -Name "UEV"
        $status = Get-UevStatus
        if ($status.UevEnabled -eq $True) {
            if ($status.UevRebootRequired -eq $True) {
                Write-Host "Reboot required to enable the UE-V service."
                exit 1
            }
            else {
                Write-Host "UE-V service is enabled."
                exit 0
            }
        }
        else {
            Write-Host "UE-V service is not enabled."
            exit 1
        }
    }
    else {
        Write-Host "UEV module not installed."
        exit 1
    }
}
else {
    Write-Host "Windows 10/11 Enterprise is required to enable UE-V."
    return 1
}
