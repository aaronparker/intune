#Requires -PSEdition Desktop
#Requires -Version 5
#Requires -RunAsAdministrator
<#PSScriptInfo

.VERSION 2.0.0

.GUID c4881872-2b2b-4711-905a-5dae9a19eafd

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2022, Aaron Parker. All rights reserved.

.TAGS UE-V Windows10 Windows11 OneDrive

.DESCRIPTION Enables and configures the UE-V service on an Intune managed Windows 10 PC

.LICENSEURI https://github.com/aaronparker/intune/blob/main/LICENSE

.PROJECTURI https://github.com/aaronparker/intune/tree/main/Uev

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    - May 2022, 2.0.0, Refactor for Proactive Remediations
    - May 2019, 1.0.0, Initial version

.PRIVATEDATA
#>
<#
    .SYNOPSIS
        Enables and configures the UE-V service on an Intune managed Windows 10/11 PC

    .DESCRIPTION
        Enables and configures the UE-V service on a Windows 10/11 PC. Downloads a set of templates from a target Azure blog storage URI and registers inbox and downloaded templates.

    .PARAMETER Uri
        Specifies the Uniform Resource Identifier (URI) of the Azure blog storage resource that hosts the UE-V templates to download.

    .PARAMETER Templates
        An array of the in-box templates to activate on the UE-V client.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com/user-experience-virtualzation-intune/

    .EXAMPLE
        Set-Uev.ps1
#>
[CmdletBinding(SupportsShouldProcess = $False, HelpURI = "https://github.com/aaronparker/intune/blob/main/Uev/README.md")]
[OutputType([System.String])]
param (
    [Parameter(Mandatory = $false)]
    [System.String] $Uri = "https://stpydeviceause.blob.core.windows.net/uev/?comp=list",

    [Parameter(Mandatory = $false)]
    # Inbox templates to enable. Templates downloaded from $Uri will be added to this list
    [System.Collections.ArrayList] $Templates = @("MicrosoftNotepad.xml", "MicrosoftWordpad.xml", "MicrosoftInternetExplorer2013.xml"),

    [Parameter(Mandatory = $false)]
    [System.String] $SettingsStoragePath = "%OneDriveCommercial%"
)

# Configure TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Functions
function Get-AzureBlobItem {
    <#
        .SYNOPSIS
            Returns an array of items and properties from an Azure blog storage URL.

        .DESCRIPTION
            Queries an Azure blog storage URL and returns an array with properties of files in a Container.
            Requires Public access level of anonymous read access to the blob storage container.
            Works with PowerShell Core.
            
        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy

        .PARAMETER Url
            The Azure blob storage container URL. The container must be enabled for anonymous read access.
            The URL must include the List Container request URI. See https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2 for more information.
        
        .EXAMPLE
            Get-AzureBlobItems -Uri "https://aaronparker.blob.core.windows.net/folder/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modified properties for each item.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://")]
        [System.String] $Uri
    )

    # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
    try {
        $iwrParams = @{
            Uri             = $Uri
            UseBasicParsing = $True
            ContentType     = "application/xml"
            ErrorAction     = "Stop"
        }
        $list = Invoke-WebRequest @iwrParams
    }
    catch [System.Net.WebException] {
        Write-Warning -Message ([System.String]::Format("Error : {0}", $_.Exception.Message))
        throw $_.Exception.Message
    }
    catch [System.Exception] {
        Write-Warning -Message "failed to download: $Uri."
        throw $_.Exception.Message
    }
    if ($Null -ne $list) {
        [System.Xml.XmlDocument] $xml = $list.Content.Substring($list.Content.IndexOf("<?xml", 0))

        # Build an object with file properties to return on the pipeline
        $fileList = New-Object -TypeName System.Collections.ArrayList
        foreach ($node in (Select-Xml -XPath "//Blobs/Blob" -Xml $xml).Node) {
            $PSObject = [PSCustomObject] @{
                Name         = $($node | Select-Object -ExpandProperty "Name")
                Url          = $($node | Select-Object -ExpandProperty "Url")
                Size         = $($node | Select-Object -ExpandProperty "Size")
                LastModified = $($node | Select-Object -ExpandProperty "LastModified")
            }
            $fileList.Add($PSObject) | Out-Null
        }
        if ($Null -ne $fileList) {
            Write-Output -InputObject $fileList
        }
    }
}

function Test-WindowsEnterprise {
    try {
        Import-Module -Name "Dism"
        $edition = Get-WindowsEdition -Online -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Error "Failed to run Get-WindowsEdition. Defaulting to False."
    }
    if ($edition.Edition -eq "Enterprise") {
        return $True
    }
    else {
        return $False
    }
}

function Get-RandomString {
    -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
}
#endregion

# If running Windows 10/11 Enterprise
if (Test-WindowsEnterprise) {

    # If the UEV module is installed, enable the UEV service
    if (Get-Module -ListAvailable -Name UEV) {

        # Enable the UE-V service
        Import-Module -Name "UEV"
        $status = Get-UevStatus
        if ($status.UevEnabled -ne $True) {
            try {
                Write-Verbose -Message "Enabling the UE-V service."
                Enable-Uev
                $status = Get-UevStatus
            }
            catch [System.Exception] {
                Write-Host "Failed to enable the UEV service with $($_.Exception.Message)."
                exit 1
            }
        }
        else {
            Write-Verbose -Message "UE-V service is enabled."
        }
        if ($status.UevRebootRequired -eq $True) {
            Write-Host "Reboot required to enable the UE-V service."
            exit 1
        }
    }
    else {
        Write-Host "UEV module not installed."
        exit 1
    }

    if ($status.UevEnabled -eq $True) {

        # Templates local target path
        $inboxTemplatesSrc = "$env:ProgramData\Microsoft\UEV\InboxTemplates"
        $templatesTemp = Join-Path -Path (Resolve-Path -Path $env:Temp) -ChildPath (Get-RandomString)
        try {
            Write-Verbose -Message "Creating temp folder: $templatesTemp."
            New-Item -Path $templatesTemp -ItemType "Directory" -Force | Out-Null
        }
        catch {
            Write-Host "Failed to create $templatesTemp with $($_.Exception.Message)."
            exit 1
        }

        # Copy the UEV templates from an Azure Storage account
        if (Test-Path -Path $inboxTemplatesSrc) {
    
            try {
                # Retrieve the list of templates from the Azure Storage account, filter for .XML files only
                $srcTemplates = Get-AzureBlobItem -Uri $Uri | Where-Object { $_.Url -match ".*.xml$" }
            }
            catch {
                Write-Host "Error at $Uri with $($_.Exception.Message)."
                exit 1
            }

            # Download each template to the target path and track success
            $downloadedTemplates = New-Object -TypeName "System.Collections.ArrayList"
            foreach ($template in $srcTemplates) {

                # Only download if the file has a .xml extension
                if ($template.Name -like "*.xml$") {
                    $targetTemplate = Join-Path -Path $templatesTemp -ChildPath $template.Name
                    try {
                        $iwrParams = @{
                            Uri             = $template.Url
                            OutFile         = $targetTemplate
                            ContentType     = "text/xml"
                            UseBasicParsing = $True
                            Headers         = @{ "x-ms-version" = "2020-04-08" }
                            ErrorAction     = "SilentlyContinue"
                        }
                        Invoke-WebRequest @iwrParams
                    }
                    catch [System.Net.WebException] {
                        $ErrorMsg = $_.Exception.Message
                        $failure = $True
                    }
                    catch [System.Exception] {
                        $ErrorMsg = $_.Exception.Message
                        $failure = $True
                    }
                    if ($failure) {
                        Write-Host "Invoke-WebRequest failed with $ErrorMsg."
                        exit 1
                    }
                    else {
                        $downloadedTemplates.Add($targetTemplate) | Out-Null
                        $Templates.Add($($template.Name)) | Out-Null
                    }
                }
            }

            # Move downloaded templates to the template store
            foreach ($template in $downloadedTemplates) {
                try {
                    Write-Verbose -Message "Moving template: $template."
                    Move-Item -Path $template -Destination $inboxTemplatesSrc -Force
                }
                catch {
                    Write-Host "Move $template failed with $($_.Exception.Message)."
                    exit 1
                }
            }

            Write-Verbose -Message "Removing temp folder: $templatesTemp."
            Remove-Item -Path $templatesTemp -Recurse -Force -ErrorAction "SilentlyContinue"

            try {
                # Unregister existing templates
                Write-Verbose -Message "Unregister existing templates."
                Get-UevTemplate | Unregister-UevTemplate -ErrorAction "SilentlyContinue"
            }
            catch {
                Write-Host "Unregister-UevTemplate failed with $($_.Exception.Message)."
                exit 1
            }

            # Register specified templates, and enable Backup mode for all templates
            foreach ($template in $Templates) {
                try {
                    Write-Verbose -Message "Registering template: $template."
                    Register-UevTemplate -Path "$inboxTemplatesSrc\$template"
                }
                catch {
                    Write-Host "Register-UevTemplate failed with $($_.Exception.Message)."
                    exit 1
                }
            }

            Get-UevTemplate | ForEach-Object { Set-UevTemplateProfile -Id $_.TemplateId -Profile "Backup" `
                    -ErrorAction "SilentlyContinue" }

            # If the templates registered successfully, configure the client
            if (Get-UevTemplate | Out-Null) {

                # Set the UEV settings. These settings will work for UEV in OneDrive with Enterprise State Roaming enabled
                # https://docs.microsoft.com/en-us/azure/active-directory/devices/enterprise-state-roaming-faqs
                try {
                    $uevParams = @{
                        Computer                            = $True
                        DisableSyncProviderPing             = $True
                        DisableWaitForSyncOnLogon           = $True
                        DisableSyncUnlistedWindows8Apps     = $True
                        EnableDontSyncWindows8AppSettings   = $True
                        EnableSettingsImportNotify          = $True
                        EnableSync                          = $True
                        EnableWaitForSyncOnApplicationStart = $True
                        SettingsStoragePath                 = $SettingsStoragePath
                        SyncMethod                          = "External"
                        WaitForSyncTimeoutInMilliseconds    = "2000"
                    }
                    Set-UevConfiguration @uevParams
                }
                catch {
                    Write-Host "Set-UevConfiguration failed with $($_.Exception.Message)."
                    exit 1
                }

                # If we got here, everything has gone well
                exit 0
            }
        }
        else {
            Write-Host "Path does not exist: $inboxTemplatesSrc."
            exit 1
        }
    }
}
else {
    Write-Host "Windows 10/11 Enterprise is required to enable UE-V."
    return 1
}
