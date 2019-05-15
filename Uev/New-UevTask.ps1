#Requires -PSEdition Desktop
#Requires -Version 3
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Creates a scheduled task to enable folder redirection at user login.
        Enable folder redirection on Windows 10 Azure AD joined PCs.
        Downloads the folder redirection script from a URL locally and creates the schedule task.
#>
[CmdletBinding(SupportsShouldProcess = $True, HelpURI = "https://github.com/aaronparker/Intune-Scripts/tree/master/Uev")]
Param (
    [Parameter()] $Uri = "https://stealthpuppy.blob.core.windows.net/scripts/?comp=list",
    [Parameter()] $Script = "Set-Uev.ps1",
    [Parameter()] $TaskName = "Download and Register UE-V Templates",
    [Parameter()] $Execute = "powershell",
    [Parameter()] $Target = "$env:ProgramData\Intune-Scripts",
    [Parameter()] $Arguments = "-NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ",
    [Parameter()] $VerbosePreference = "Continue"
)

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
            Get-AzureBlobItems -Uri "https://aaronparker.blob.core.windows.net/folder/?comp=list"

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
    Try { $list = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction Stop } Catch [Exception] { Write-Warning $_; Break }
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
#endregion

$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile

# If local path for script doesn't exist, create it
If (!(Test-Path -Path $Target)) { 
    Write-Verbose "Creating folder: $templatesTemp."
    New-Item -Path $Target -Type Directory -Force | Out-Null
}

# Retrieve the list of scripts from the Azure Storage account and save locally
$script = Get-AzureBlobItem -Uri $Uri | Where-Object { $_.Name -eq $Script } | Select-Object -First 1
$targetScript = Join-Path $Target $script.Name
Invoke-WebRequest -Uri $script.Url -OutFile $targetScript -UseBasicParsing `
    -Headers @{ "x-ms-version" = "2015-02-21" } -ErrorAction SilentlyContinue
If (Test-Path -Path $targetScript) { Write-Verbose "$targetScript downloaded successfully." }
$Arguments = "$Arguments $targetScript"

# Get an existing local task if it exists
If ($Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { 

    Write-Verbose "Scheduled task exists."
    # If the task Action differs from what we have above, update the values and save the task
    If (!(($Task.Actions[0].Execute -eq $Execute) -and ($Task.Actions[0].Arguments -eq $Arguments))) {
        Write-Verbose "Updating scheduled task."
        $Task.Actions[0].Execute = $Execute
        $Task.Actions[0].Arguments = $Arguments
        $Task | Set-ScheduledTask -Verbose
    }
    Else {
        Write-Verbose "Existing task action is OK, no change required."
    }
}
Else {
    Write-Verbose "Creating scheduled task."
    # Build a new task object
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
    $trigger = New-ScheduledTaskTrigger -Daily -At 1pm
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden `
        -DontStopIfGoingOnBatteries -Compatibility Win8 -RunOnlyIfNetworkAvailable
    $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $newTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    # No task object exists, so register the new task
    Write-Verbose "Registering new task $TaskName."
    Register-ScheduledTask -InputObject $newTask -TaskName $TaskName -TaskPath "\Microsoft\UE-V" -Verbose
}

Stop-Transcript
