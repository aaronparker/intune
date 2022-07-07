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

    .PARAMETER CustomTemplatesPath
        Directory path where custom UE-V templates will be saved into.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com/user-experience-virtualzation-intune/

    .EXAMPLE
        Invoke-Uev.ps1
#>
[CmdletBinding(SupportsShouldProcess = $False, HelpURI = "https://github.com/aaronparker/intune/blob/main/Uev/README.md")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Output required by Proactive Remediations.")]
param (
    [Parameter(Mandatory = $false)]
    [System.String] $Uri = "https://stpydeviceause.blob.core.windows.net/uev/?comp=list",

    [Parameter(Mandatory = $false)]
    [System.String] $CustomTemplatesPath = "$env:ProgramData\Microsoft\UEV\CustomTemplates"
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

    begin {}
    process {
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
                    Uri          = $($node | Select-Object -ExpandProperty "Url")
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
}

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

function Get-RandomString {
    -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
}
#endregion

# If running Windows 10/11 Enterprise
if (Test-WindowsEnterprise) {

    # If the UEV module is installed, enable the UEV service
    if (Get-Module -ListAvailable -Name "UEV") {

        # Enable the UE-V service
        Import-Module -Name "UEV"
        $status = Get-UevStatus
        if ($status.UevEnabled -eq $True) {
            if ($status.UevRebootRequired -eq $True) {
                Write-Verbose -Message "Reboot required to enable the UE-V service."
            }
            else {
                Write-Verbose -Message "UE-V service is enabled."
            }
        }
        else {
            try {
                Write-Verbose -Message "Enabling the UE-V service."
                Enable-Uev
                $status = Get-UevStatus
            }
            catch [System.Exception] {
                Write-Host "Failed to enable the UEV service with $($_.Exception.Message)."
                exit 1
            }
            if ($status.UevEnabled -eq $True) {
                Write-Verbose -Message "UE-V service is enabled."
            }
            else {
                Write-Verbose -Message "UE-V service is not enabled."
            }
        }
    }
    else {
        Write-Host "UEV module not installed."
        exit 1
    }

    if ($status.UevEnabled -eq $True) {

        # Templates local target path
        $templatesTemp = Join-Path -Path (Resolve-Path -Path $env:Temp) -ChildPath (Get-RandomString)
        try {
            Write-Verbose -Message "Creating temp folder: $templatesTemp."
            New-Item -Path $templatesTemp -ItemType "Directory" -Force | Out-Null
        }
        catch {
            Write-Host "Failed to create $templatesTemp with $($_.Exception.Message)."
            exit 1
        }

        try {
            Write-Verbose -Message "Creating custom templates folder: $CustomTemplatesPath."
            New-Item -Path $CustomTemplatesPath -ItemType "Directory" -Force | Out-Null
        }
        catch {
            Write-Host "Failed to create $CustomTemplatesPath with $($_.Exception.Message)."
            exit 1
        }

        # Copy the UEV templates from an Azure Storage account
        if (Test-Path -Path $CustomTemplatesPath) {
            try {
                # Retrieve the list of templates from the Azure Storage account, filter for .XML files only
                $SrcTemplates = Get-AzureBlobItem -Uri $Uri | Where-Object { $_.Uri -match ".*.xml$" }
            }
            catch {
                Write-Host "Error at $Uri with $($_.Exception.Message)."
                exit 1
            }

            # Download each template to the target path and track success
            $downloadedTemplates = New-Object -TypeName "System.Collections.ArrayList"
            foreach ($template in $SrcTemplates) {

                # Only download if the file has a .xml extension
                if ($template.Name -match ".xml$") {
                    $targetTemplate = Join-Path -Path $templatesTemp -ChildPath $template.Name
                    try {
                        $iwrParams = @{
                            Uri             = $template.Uri
                            OutFile         = $targetTemplate
                            ContentType     = "text/xml"
                            UseBasicParsing = $True
                            Headers         = @{ "x-ms-version" = "2020-04-08" }
                            ErrorAction     = "SilentlyContinue"
                        }
                        Invoke-WebRequest @iwrParams
                    }
                    catch [System.Exception] {
                        Write-Host "Invoke-WebRequest failed with $($_.Exception.Message)."
                        exit 1
                    }
                }
                $downloadedTemplates.Add($targetTemplate) | Out-Null
                $Templates.Add($($template.Name)) | Out-Null
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

        Write-Host "UE-V service enabled. Custom templates downloaded. Configure agent via policy."
        exit 0
    }
    else {
        Write-Host "UE-V service not enabled."
        exit 1
    }
}
else {
    Write-Host "Windows 10/11 Enterprise is required to enable UE-V."
    return 1
}
