#Requires -PSEdition Desktop
#Requires -Version 3
#Requires -RunAsAdministrator
<#PSScriptInfo

.VERSION 1.0.0

.GUID c4881872-2b2b-4711-905a-5dae9a19eafd

.AUTHOR Aaron Parker

.COMPANYNAME stealthpuppy

.COPYRIGHT 2019, Aaron Parker. All rights reserved.

.TAGS UE-V Windows10 Profile-Container

.DESCRIPTION Enables and configures the UE-V service on an Intune managed Windows 10 PC

.LICENSEURI https://github.com/aaronparker/Intune-Scripts/blob/master/LICENSE

.PROJECTURI https://github.com/aaronparker/Intune-Scripts/tree/master/Redirections

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
    - May 2019, 1.0.0, Initial version

.PRIVATEDATA
#>
<#
    .SYNOPSIS
        Enables and configures the UE-V service on an Intune managed Windows 10 PC

    .DESCRIPTION
        Enables and configures the UE-V service on a Windows 10 PC. Downloads a set of templates from a target Azure blog storage URI and registers inbox and downloaded templates.

    .PARAMETER Uri
        Specifies the Uniform Resource Identifier (URI) of the Azure blog storage resource that hosts the UE-V templates to download.

    .PARAMETER Templates
        An array of the in-box templates to activate on the UE-V client.

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy

    .LINK
        https://stealthpuppy.com

    .EXAMPLE
        Set-Uev.ps1
#>
[CmdletBinding(SupportsShouldProcess = $True, HelpURI = "https://github.com/aaronparker/Intune-Scripts/tree/master/Uev")]
[OutputType([String])]
Param (
    [Parameter(Mandatory = $false)]
    [string] $Uri = "https://stealthpuppy.blob.core.windows.net/uevtemplates/?comp=list",

    [Parameter(Mandatory = $false)]
    # Inbox templates to enable. Templates downloaded from $Uri will be added to this list
    [string[]] $Templates = @("MicrosoftNotepad.xml", "MicrosoftWordpad.xml", "MicrosoftInternetExplorer2013.xml")
)

# Configure
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Functions
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
            Get-AzureBlobItems -Url "https://aaronparker.blob.core.windows.net/folder/?comp=list"

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

Function Test-Windows10Enterprise {
    Try {
        $edition = Get-WindowsEdition -Online -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Error "Failed to run Get-WindowsEdition. Defaulting to False."
    }
    If ($edition.Edition -eq "Enterprise") {
        Write-Output $True
    }
    Else {
        Write-Output $False
    }
}

Function Get-RandomString {
    -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
}
#endregion

# If running Windows 10 Enterprise
If (Test-Windows10Enterprise) {

    # If the UEV module is installed, enable the UEV service
    If (Get-Module -ListAvailable -Name UEV) {
        Import-Module -Name UEV

        # Enable the UE-V service
        $status = Get-UevStatus
        If ($status.UevEnabled -ne $True) {
            Write-Verbose -Message "Enabling the UE-V service."
            Enable-Uev
            $status = Get-UevStatus
        }
        Else {
            Write-Verbose "UE-V service is enabled."
        }
        If ($status.UevRebootRequired -eq $True) {
            Write-Warning "Reboot required to enable the UE-V service."
        }
    }
    Else {
        Write-Error "UEV module not installed."
    }

    # Determine the UEV settings storage path in the OneDrive folder
    If (Test-Path -Path "env:OneDriveCommercial") {
        $settingsStoragePath = "%OneDriveCommercial%"
        Write-Verbose -Message "UE-V Settings Storage Path is $settingsStoragePath."
    }
    ElseIf (Test-Path -Path "env:OneDrive") {
        $settingsStoragePath = "%OneDrive%"
        Write-Verbose -Message "UE-V Settings Storage Path is $settingsStoragePath."
    }
    Else {
        Write-Warning "OneDrive path not found."
    }

    # Set the UEV settings. These settings will work for UEV in OneDrive with Enterprise State Roaming enabled
    # https://docs.microsoft.com/en-us/azure/active-directory/devices/enterprise-state-roaming-faqs
    If ($status.UevEnabled -eq $True) {
        $UevParams = @{
            Computer                            = $True
            DisableSyncProviderPing             = $True
            DisableWaitForSyncOnLogon           = $True
            DisableSyncUnlistedWindows8Apps     = $True
            EnableDontSyncWindows8AppSettings   = $True
            EnableSettingsImportNotify          = $True
            EnableSync                          = $True
            EnableWaitForSyncOnApplicationStart = $True
            SettingsStoragePath                 = $settingsStoragePath
            SyncMethod                          = "External"
            WaitForSyncTimeoutInMilliseconds    = "2000"
        }
        Set-UevConfiguration @UevParams
    }

    # Templates local target path
    $inboxTemplatesSrc = "$env:ProgramData\Microsoft\UEV\InboxTemplates"
    $templatesTemp = Join-Path (Resolve-Path -Path $env:Temp) (Get-RandomString)
    New-Item -Path $templatesTemp -ItemType Directory -Force

    # Copy the UEV templates from an Azure Storage account
    If (Test-Path -Path $inboxTemplatesSrc) {
    
        # Retrieve the list of templates from the Azure Storage account
        $srcTemplates = Get-AzureBlobItem -Uri $Uri

        # Download each template to the target path and track success
        ForEach ($template in $srcTemplates) {
            Try {
                $target = "$templatesTemp\$(Split-Path -Path $template.Url -Leaf)"
                Invoke-WebRequest -Uri $template.Url -OutFile $target -UseBasicParsing `
                    -Headers @{ "x-ms-version" = "2015-02-21" } -ErrorAction SilentlyContinue
            }
            Catch {
                $failure = $True
            }
            If (!($failure)) {
                $downloadedTemplates += $target
                $Templates += $(Split-Path -Path $template.Url -Leaf)
            }            
        }

        # Move downloaded templates to the template store
        ForEach ($template in $downloadedTemplates) {
            Move-Item -Path $template -Destination $inboxTemplatesSrc -Force
        }

        # Unregister existing templates
        Get-UevTemplate | Unregister-UevTemplate -ErrorAction SilentlyContinue

        # Register specified templates
        ForEach ($template in $Templates) {
            Register-UevTemplate -Path "$inboxTemplatesSrc\$template"
        }
    }
    Else {
        Write-Warning "Path does not exist: $inboxTemplatesSrc."
    }
}
Else {
    Write-Warning "Windows 10 Enterprise is required to enable UE-V."
}
