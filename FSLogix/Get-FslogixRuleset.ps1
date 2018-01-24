<#
    .SYNOPSIS
        Gets an FSLogix App Masking ruleset from a specified location; Downloads to the local rules folder.
        Enables rulset distribution for FSLogix Agents deployed across Windows 10 Modern Management.

    .DESCRIPTION
        
    .NOTES
        Name: Get-FslogixRuleset.ps1
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com
#>
#Requires -Version 3

# Common Variables
$VerbosePreference = "Continue"
$Target = "$env:ProgramData\Scripts"
Start-Transcript -Path "$Target\$($MyInvocation.MyCommand.Name).log"

Function Get-AzureBlobItems {
    <#
        .SYNOPSIS
            Returns an array of items and properties from an Azure blog storage URL.

        .DESCRIPTION
            Queries an Azure blog storage URL and returns an array with properties of files in a Container.
            Requires Public access level of anonymous read access to the blob storage container.
            Works with PowerShell Core.
            
        .NOTES
            Name: Get-AzureBlobItems
            Author: Aaron Parker
            Twitter: @stealthpuppy

        .LINK
            https://stealthpuppy.com

        .PARAMETER Url
            The Azure blob storage container URL. The container must be enabled for anonymous read access.
            The URL must include the List Container request URI. See https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2 for more information.
        
        .EXAMPLE
            Get-AzureBlobItems -Url "https://aaronparker.blob.core.windows.net/folder/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modifed properties for each item.

        .OUTPUTS
            Returns System.Array
    #>
    #Requires -Version 3
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://")]
        [string]$Url
    )

    # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
    Write-Verbose "Getting content from $Url";
    Try { $List = Invoke-WebRequest -Uri $Url -ErrorAction Stop -Verbose } Catch [Exception] { Write-Host $_; Break  }
    [xml]$Xml = $List.Content.Substring($list.Content.IndexOf("<?xml",0))

    # Build an object with file properties to return on the pipeline
    Write-Verbose "Building files object from downloaded XML."
    $Output =@()
    ForEach ( $Node in (Select-Xml -XPath "//Blobs/Blob" -Xml $Xml).Node ) {
        $Item = New-Object -TypeName PSObject
        $Item | Add-Member -Type NoteProperty -Name 'Name' -Value ($Node | Select-Object -ExpandProperty Name)
        $Item | Add-Member -Type NoteProperty -Name 'Url' -Value ($Node | Select-Object -ExpandProperty Url)
        $Item | Add-Member -Type NoteProperty -Name 'Size' -Value ($Node | Select-Object -ExpandProperty Size)
        $Item | Add-Member -Type NoteProperty -Name 'LastModified' -Value ($Node | Select-Object -ExpandProperty LastModified)
        $Output += $Item
    }
    Return $Output
}

#Variables
$Source = "https://stlhppymdrn.blob.core.windows.net/fslogix/?comp=list"
$RegPath = "HKLM:\SOFTWARE\FSLogix\Apps"
$RegExDirectory = "^[a-zA-Z]:\\[\\\S|*\S]?.*$"

# Get the FSLogix Agent CompiledRules folder from path stored in the registry
If (Test-Path -Path $RegPath) {
    $RulesFolder = "$((Get-ItemProperty -Path $RegPath -Name "InstallPath").InstallPath)CompiledRules"
    Write-Verbose "Got $RulesFolder from the registry."
} Else {
    Write-Error "Unable to find FSLogix Apps registry entry. Is the agent installed?"
    Break
}

# Test $RulesFolder and create if it doesn't exist; Get files in existing FSLogix agent rules folder
If ($RulesFolder -match $RegExDirectory) {
    Write-Verbose "Path from registry looks OK: $RulesFolder"
    If (!(Test-Path -Path $RulesFolder)) { Write-Verbose "$RulesFolder doesn't exist. Creating."; New-Item -Path $RulesFolder -ItemType Directory }
    $ExistingRuleSet = Get-ChildItem -Path $RulesFolder
} Else {
    Write-Error "$RulesFolder doesn't look like a valid folder path. Please check."
    Break
}

# Get list of the rules files from the Azure blob storage
If ($NewRuleset = Get-AzureBlobItems -Url $Source) {

    # Remove files in the existing rules folder that are different from the new ruleset
    ForEach ( $file in ($ExistingRuleSet.Name | Where-Object { $NewRuleset.Name -notcontains $_ }) ) {
        Write-Verbose "Removing: $RulesFolder\$file"
        Remove-Item -Path "$RulesFolder\$file" -Force
    }

    # Download each of the new ruleset files
    ForEach ( $file in $NewRuleset ) {
        Write-Verbose "Downloading: $($file.url) to $RulesFolder\$($file.name)"
        Start-BitsTransfer -Source $file.url -Destination "$RulesFolder\$($file.name)"
    }
}

Stop-Transcript