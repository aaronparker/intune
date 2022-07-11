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
    catch [System.Exception] {
        Write-Error -Message "Failed to run Get-WindowsEdition. Defaulting to False."
    }
    if ($edition.Edition -eq "Enterprise") {
        return $True
    }
    else {
        return $False
    }
}
function Write-ToEventLog ($Message) {
    switch -Regex ($Message) {
        "^Information" {
            $EntryType = "Information"
            $Number = 0
        }
        "^Warning" {
            $EntryType = "Warning"
            $Number = 1
        }
        "^Error" {
            $EntryType = "Error"
            $Number = 2
        }
        default {
            $EntryType = "Information"
            $Number = 0
        }
    }
    $params = @{
        LogName     = "Application"
        Source      = "UevProactiveRemediation"
        EventID     = (8000 + $Number)
        EntryType   = $EntryType
        Message     = $Message
        ErrorAction = "SilentlyContinue"
    }
    Write-EventLog @params
}
#endregion

# Create a new event log source
$params = @{
    LogName     = "Application"
    Source      = "UevProactiveRemediation"
    ErrorAction = "SilentlyContinue"
}
New-EventLog @params

# If running Windows 10/11 Enterprise
if (Test-WindowsEnterprise) {

    # If the UEV module is installed
    if (Get-Module -ListAvailable -Name "UEV") {

        # Detect the UE-V service
        Import-Module -Name "UEV"
        $status = Get-UevStatus
        if ($status.UevEnabled -eq $True) {
            $Message = "Detection result:"
            $Result = 0

            try {
                # Retrieve the list of templates from the Azure Storage account, filter for .XML files only
                $SrcTemplates = Get-AzureBlobItem -Uri $Uri | Where-Object { $_.Uri -match ".*.xml$" }
            }
            catch [System.Exception] {
                $Message += "`nError at $Uri with $($_.Exception.Message)."
                $Result = 1
            }

            # Validate the local copy of the custom templates against the Azure Storage account
            $CustomTemplates = $(Get-ChildItem -Path $CustomTemplatesPath -Filter "*.xml" -ErrorAction "SilentlyContinue").Name
            $params = @{
                ReferenceObject  = $SrcTemplates.Name
                DifferenceObject = $CustomTemplates
                ErrorAction      = "SilentlyContinue"
            }
            if (($Null -eq $CustomTemplates) -or ($Null -ne (Compare-Object @params))) {
                Write-ToEventLog -Message "Error: Local templates in $CustomTemplates do not match $Uri."
                $Message += "`nLocal templates in $CustomTemplates do not match $Uri."
                $Result = 1
            }

            # Check whether templates are registered
            $RegisteredTemplates = Get-UevTemplate -ErrorAction "SilentlyContinue"
            if ($Null -eq $RegisteredTemplates) {
                Write-ToEventLog -Message "Error: No settings templates are registered."
                $Message += "`nNo settings templates are registered."
                $Result = 1
            }

            # Check whether a reboot is required
            if ($status.UevRebootRequired -eq $True) {
                Write-ToEventLog -Message "Warning: Reboot required to enable the UE-V service."
                $Message += "`nReboot required to enable the UE-V service."
                $Result = 1
            }

            # Exit with an error
            if ($Result -eq 1) {
                Write-Host $Message
                exit $Result
            }
            else {
                # If we get here, all is good
                Write-ToEventLog -Message "UE-V service is enabled. $($RegisteredTemplates.Count) settings templates are registered."
                Write-Host "UE-V service is enabled. $($RegisteredTemplates.Count) settings templates are registered."
                exit 0
            }
        }
        else {
            Write-ToEventLog -Message "Warning: UE-V service is not enabled."
            Write-Host "UE-V service is not enabled."
            exit 1
        }
    }
    else {
        Write-ToEventLog -Message "Error: UEV module not installed."
        Write-Host "UEV module not installed."
        exit 1
    }
}
else {
    Write-ToEventLog -Message "Warning: Windows 10/11 Enterprise is required to enable UE-V."
    Write-Host "Windows 10/11 Enterprise is required to enable UE-V."
    exit 1
}
