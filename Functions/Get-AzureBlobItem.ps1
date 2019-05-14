Function Get-AzureBlobItem {
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

        .LINK
            https://stealthpuppy.com

        .PARAMETER Url
            The Azure blob storage container URL. The container must be enabled for anonymous read access.
            The URL must include the List Container request URI. See https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2 for more information.
        
        .EXAMPLE
            Get-AzureBlobItem -Url "https://aaronparker.blob.core.windows.net/folder/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modifed properties for each item.

        .OUTPUTS
            Returns System.Array
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://")]
        [string] $Uri
    )

    # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
    Try { $list = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop } Catch [Exception] { Write-Host $_; Break }
    [xml] $xml = $list.Content.Substring($list.Content.IndexOf("<?xml", 0))

    # Build an object with file properties to return on the pipeline
    $output = @()
    ForEach ($node in (Select-Xml -XPath "//Blobs/Blob" -Xml $Xml).Node) {
        $item = New-Object -TypeName PSObject
        $item | Add-Member -Type NoteProperty -Name 'Name' -Value ($node | Select-Object -ExpandProperty Name)
        $item | Add-Member -Type NoteProperty -Name 'Url' -Value ($node | Select-Object -ExpandProperty Url)
        $item | Add-Member -Type NoteProperty -Name 'Size' -Value ($node | Select-Object -ExpandProperty Size)
        $item | Add-Member -Type NoteProperty -Name 'LastModified' -Value ($node | Select-Object -ExpandProperty LastModified)
        $output += $item
    }
    Write-Output $output
}
