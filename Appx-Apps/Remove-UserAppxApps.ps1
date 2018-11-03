<#
        .SYNOPSIS
            Removes a specified list of AppX packages from the current system.
 
        .DESCRIPTION
            Removes a specified list of AppX packages from the current user account and the local system
            to prevent new installs of in-built apps when new users log onto the system. Return True or 
            False to flag whether the system requires a reboot as a result of removing the packages.

        .PARAMETER Operation
            Specify the AppX removal operation - either Blacklist or Whitelist. 

        .PARAMETER Blacklist
            Specify an array of AppX packages to 'blacklist' or remove from the current Windows instance,
            all other apps will remain installed. The script will use the blacklist by default.
  
        .PARAMETER Whitelist
            Specify an array of AppX packages to 'whitelist' or keep in the current Windows instance.
            All apps except this list will be removed from the current Windows instance.

        .EXAMPLE
            PS C:\> Remove-AppxApps -Operation Blacklist
            
            Remove the default list of Blacklisted AppX packages stored in the function.
 
        .EXAMPLE
            PS C:\> Remove-AppxApps -Operation Whitelist
            
            Remove the default list of Whitelisted AppX packages stored in the function.

         .EXAMPLE
            PS C:\> Remove-AppxApps -Operation Blacklist -Blacklist "Microsoft.3DBuilder_8wekyb3d8bbwe", "Microsoft.XboxApp_8wekyb3d8bbwe"
            
            Remove a specific set of AppX packages a specified in the -Blacklist argument.
 
         .EXAMPLE
            PS C:\> Remove-AppxApps -Operation Whitelist -Whitelist "Microsoft.BingNews_8wekyb3d8bbwe", "Microsoft.BingWeather_8wekyb3d8bbwe"
            
            Remove AppX packages from the system except those specified in the -Whitelist argument.

        .NOTES
 	        NAME: Remove-UserAppxApps.ps1
	        VERSION: 2.0
	        AUTHOR: Aaron Parker
	        TWITTER: @stealthpuppy
 
        .LINK
            http://stealthpuppy.com
    #>
[CmdletBinding(DefaultParameterSetName = "Blacklist")]
Param (
    [Parameter(Mandatory = $false, ParameterSetName = "Blacklist", HelpMessage = "Specify whether the operation is a blacklist or whitelist.")]
    [Parameter(Mandatory = $false, ParameterSetName = "Whitelist", HelpMessage = "Specify whether the operation is a blacklist or whitelist.")]
    [ValidateSet('Blacklist', 'Whitelist')]
    [string] $Operation = "Blacklist",

    [Parameter(Mandatory = $false, ParameterSetName = "Blacklist", HelpMessage = "Specify an AppX package or packages to remove.")]
    [array] $Blacklist = ( "Microsoft.3DBuilder_8wekyb3d8bbwe", `
            "Microsoft.BingFinance_8wekyb3d8bbwe", `
            "Microsoft.BingSports_8wekyb3d8bbwe", `
            "Microsoft.ConnectivityStore_8wekyb3d8bbwe", `
            "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe", `
            "Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe", `
            "Microsoft.SkypeApp_kzf8qxf38zg5c", `
            "Microsoft.WindowsPhone_8wekyb3d8bbwe", `
            "Microsoft.XboxApp_8wekyb3d8bbwe", `
            "Microsoft.ZuneMusic_8wekyb3d8bbwe", `
            "Microsoft.ZuneVideo_8wekyb3d8bbwe", `
            "Microsoft.OneConnect_8wekyb3d8bbwe", `
            "king.com.CandyCrushSodaSaga_kgqvnymyfvs32", `
            "Microsoft.Office.Desktop.Access_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop.Excel_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop.Outlook_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop.PowerPoint_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop.Publisher_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop.Word_8wekyb3d8bbwe", `
            "Microsoft.Office.Desktop_8wekyb3d8bbwe", `
            "7EE7776C.LinkedInforWindows_w1wdnht996qgy" ),
        
    [Parameter(Mandatory = $false, ParameterSetName = "Whitelist", HelpMessage = "Specify an AppX package or packages to keep, removing all others.")]
    [array] $Whitelist = ( "Microsoft.BingWeather_8wekyb3d8bbwe", `
            "Microsoft.Office.OneNote_8wekyb3d8bbwe", `
            "Microsoft.People_8wekyb3d8bbwe", `
            "Microsoft.Windows.Photos_8wekyb3d8bbwe", `
            "Microsoft.WindowsAlarms_8wekyb3d8bbwe", `
            "Microsoft.WindowsCalculator_8wekyb3d8bbwe", `
            "Microsoft.WindowsCamera_8wekyb3d8bbwe", `
            "microsoft.windowscommunicationsapps_8wekyb3d8bbwe", `
            "Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe", `
            "Microsoft.WindowsStore_8wekyb3d8bbwe", `
            "Microsoft.MicrosoftEdge_8wekyb3d8bbwe", `
            "Microsoft.Windows.Cortana_cw5n1h2txyewy", `
            "Microsoft.Windows.FeatureOnDemand.InsiderHub_cw5n1h2txyewy", `
            "Microsoft.WindowsFeedback_cw5n1h2txyewy", `
            "Microsoft.WindowsMaps_8wekyb3d8bbwe", `
            "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe", `
            "Microsoft.GetHelp_8wekyb3d8bbwe", `
            "Microsoft.Getstarted_8wekyb3d8bbwe", `
            "Microsoft.StorePurchaseApp_8wekyb3d8bbwe", `
            "Microsoft.Wallet_8wekyb3d8bbwe" )
)
Begin {
    # A set of apps that we'll never try to remove
    [array] $protectList = ( "Microsoft.WindowsStore_8wekyb3d8bbwe", `
            "Microsoft.MicrosoftEdge_8wekyb3d8bbwe", `
            "Microsoft.Windows.Cortana_cw5n1h2txyewy", `
            "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe", `
            "Microsoft.StorePurchaseApp_8wekyb3d8bbwe", `
            "Microsoft.Wallet_8wekyb3d8bbwe" )
}
Process {
    # Start logging
    $LogFile = "$env:LocalAppData\Intune-PowerShell-Logs\Remove-UserAppxApps.log"
    Start-Transcript -Path $LogFile

    Switch ($Operation) {

        "Blacklist" {
            # Filter list if it contains apps from the $protectList
            $apps = Compare-Object -ReferenceObject $Blacklist -DifferenceObject $protectList -PassThru | Where-Object { $_.SideIndicator -eq "<=" }
        }

        "Whitelist" {
            # Get packages from the current system and filter out the whitelisted apps
            $allPackages = @()
            $packages = Get-AppxProvisionedPackage -Online | Select-Object DisplayName
            ForEach ( $package in $packages) {
                $allPackages += Get-AppxPackage -AllUsers -Name $package.DisplayName | Select-Object PackageFamilyName
            }
            $apps = Compare-Object -ReferenceObject $allPackages.PackageFamilyName -DifferenceObject $Whitelist -PassThru | Where-Object { $_.SideIndicator -eq "<=" }

            # Ensure the list does not contain a system app
            $systemApps = Get-AppxPackage -AllUsers | Where-Object { $_.InstallLocation -like "$env:SystemRoot\SystemApps*" -or $_.IsFramework -eq $True } | Select-Object PackageFamilyName
            $apps = Compare-Object -ReferenceObject $apps -DifferenceObject $systemApps.PackageFamilyName -PassThru | Where-Object { $_.SideIndicator -eq "<=" }

            # Ensure the list does not contain an app from the $protectList
            $apps = Compare-Object -ReferenceObject $apps -DifferenceObject $protectList -PassThru | Where-Object { $_.SideIndicator -eq "<=" }
        }
    }

    # Remove the apps; Walk through each package in the array
    $output = @()
    ForEach ( $app in $apps ) {
                
        # Get the AppX package object by passing the string to the left of the underscore
        # to Get-AppxPackage and passing the resulting package object to Remove-AppxPackage
        $package = Get-AppxPackage -Name (($app -split "_")[0])
        If ($package) {
            $package | Remove-AppxPackage -Verbose
            $item = New-Object PSObject
            $item | Add-Member -type NoteProperty -Name 'RemovedPackage' -Value $app
            $output += $item
        }            
    }
}
End {
    Return $output
    Stop-Transcript
}
