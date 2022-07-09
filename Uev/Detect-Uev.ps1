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
param (
    [Parameter(Mandatory = $false)]
    [System.String] $Uri = "https://stpydeviceause.blob.core.windows.net/uev/?comp=list",

    [Parameter(Mandatory = $false)]
    [System.String] $CustomTemplatesPath = "$env:ProgramData\Microsoft\UEV\CustomTemplates"
)

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

                try {
                    # Retrieve the list of templates from the Azure Storage account, filter for .XML files only
                    $SrcTemplates = Get-AzureBlobItem -Uri $Uri | Where-Object { $_.Uri -match ".*.xml$" }
                }
                catch {
                    Write-Host "Error at $Uri with $($_.Exception.Message)."
                    exit 1
                }

                # Validate the local copy of the custom templates against the Azure Storage account
                $CustomTemplates = $(Get-ChildItem -Path $CustomTemplatesPath -Filter "*.xml" -ErrorAction "SilentlyContinue").Name
                $params = @{
                    ReferenceObject  = $SrcTemplates.Name
                    DifferenceObject = $CustomTemplates
                    ErrorAction      = "SilentlyContinue"
                }
                if (($Null -eq $CustomTemplates) -or ($Null -ne (Compare-Object @params))) {
                    Write-Host "Local custom templates do not match $CustomTemplatesPath."
                    exit 1
                }

                # If we get here, all is good
                Write-Host "UE-V service is enabled. Custom templates are good."
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
