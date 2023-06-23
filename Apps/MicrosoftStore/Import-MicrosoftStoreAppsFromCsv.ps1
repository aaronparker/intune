<#
    .SYNOPSIS
        Import Microsoft Store apps from a simple CSV file into Intune with an icon

    .NOTES
        Original code sourced from:
        https://www.rozemuller.com/add-microsoft-store-app-with-icon-into-intune-automated/
        https://github.com/srozemuller/MicrosoftEndpointManager/blob/main/Deployment/Applications/deploy-win-store-app.ps1
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $AuthFile = "$PSScriptRoot\auth.json",

    [Parameter()]
    [System.String] $AppList = "$PSScriptRoot\StoreApps.csv",

    [Parameter()]
    [System.Management.Automation.SwitchParameter] $AddAssignment
)

begin {
    function Write-Msg ($Msg) {
        $params = @{
            MessageData       = "$Msg"
            InformationAction = "Continue"
            Tags              = "Intune"
        }
        Write-Information @params
    }

    # Don't show a progress bar for Invoke-WebRequest and Invoke-RestMethod
    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    # Read the secrets file
    Write-Msg -Msg "Import secrets from '$AuthFile'."
    $Secrets = Get-Content -Path $AuthFile -ErrorAction "Stop" | ConvertFrom-Json -ErrorAction "Stop"

    try {
        #region Authenticate to the Microsoft Graph
        $body = @{
            grant_Type    = "client_credentials"
            scope         = "https://graph.microsoft.com/.default"
            client_Id     = $Secrets.ClientId
            client_Secret = $Secrets.ClientSecret
        }
        $params = @{
            Uri         = "https://login.microsoftonline.com/{0}/oauth2/v2.0/token" -f $Secrets.TenantId
            Method      = "POST"
            Body        = $body
            ErrorAction = "Stop"
        }
        Write-Msg -Msg "Authenticate to the Microsoft Graph.`r`n"
        $connect = Invoke-RestMethod @params

        $authHeader = @{
            'Content-Type' = 'application/json'
            Authorization  = 'Bearer ' + $connect.access_token
        }
        #endregion
    }
    catch {
        throw $_
    }

    # Read apps list
    Write-Msg -Msg "Import applications list from '$AppList'.`r`n"
    $Apps = Import-Csv -Path $AppList -ErrorAction "Stop"
}

process {
    foreach ($App in $Apps) {
        Write-Msg -Msg "Importing application: '$($App.DisplayName), $($App.PackageIdentifier)'."

        #region Get details for the app
        Write-Msg -Msg "Perform application manifest search in the Microsoft Store."
        $appUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/{0}" -f $App.PackageIdentifier
        $appManifest = Invoke-RestMethod -Uri $appUrl -Method "GET" -ErrorAction "Stop"
        $appInfo = $appManifest.Data.Versions[-1].DefaultLocale
        #endregion

        #region Get the icon for the app
        Write-Msg -Msg "Get the icon for this application."
        $imageUrl = "https://apps.microsoft.com/store/api/ProductsDetails/GetProductDetailsById/{0}?hl=en-US&gl=US" -f $App.PackageIdentifier
        $image = Invoke-RestMethod -Uri $imageUrl -Method "GET" -ErrorAction "Stop"
        $base64Icon = [System.Convert]::ToBase64String((Invoke-WebRequest -Uri $image.IconUrl -ErrorAction "Stop").Content)
        #endregion

        #region Import the app into Intune
        $appBody = @{
            '@odata.type'         = "#microsoft.graph.winGetApp"
            description           = $appInfo.ShortDescription
            developer             = $appInfo.Publisher
            displayName           = $appInfo.packageName
            informationUrl        = if ([System.String]::IsNullOrEmpty($appInfo.PublisherSupportUrl)) { $null } elseif ($appInfo.PublisherSupportUrl -match "^http") { $appInfo.PublisherSupportUrl } else { "https://$($appInfo.PublisherSupportUrl)" }
            largeIcon             = @{
                "@odata.type" = "#microsoft.graph.mimeContent"
                "type"        = "image/png"
                "value"       = $base64Icon
            }
            installExperience     = @{
                runAsAccount = $App.InstallAs
            }
            isFeatured            = $false
            packageIdentifier     = $appManifest.Data.PackageIdentifier
            privacyInformationUrl = if ([System.String]::IsNullOrEmpty($appInfo.PrivacyUrl)) { $null } elseif ($appInfo.PrivacyUrl -match "^http") { $appInfo.PrivacyUrl } else { "https://$($appInfo.PrivacyUrl)" }
            publisher             = $appInfo.publisher
            repositoryType        = "microsoftStore"
            roleScopeTagIds       = @()
        } | ConvertTo-Json -ErrorAction "Stop"
        $params = @{
            Uri         = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
            Method      = "POST"
            Headers     = $authHeader
            Body        = $appBody
            ErrorAction = "Stop"
        }
        Write-Msg -Msg "Import the application into Microsoft Intune."
        if ($appManifest.Data.Versions.Installers[-1].Scope -ne $App.InstallAs) { Write-Msg -Msg "Changing install as from '$($appManifest.Data.Versions.Installers[-1].Scope)' to '$(App.InstallAs)'" }
        $appDeploy = Invoke-RestMethod @params
        Start-Sleep -Seconds 3 # Wait for the application to be imported. Avoids having to make a call back to the API to check on import status
        #endregion

        #region Configure the app assignment
        if (-not([System.String]::IsNullOrEmpty($App.AssignmentTarget))) {
            $mobileAppAssignments = @()
            switch ($App.AssignmentTarget) {
                "AllDevices" {
                    $mobileAppAssignments += @{
                        "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                        target        = @{
                            "@odata.type" = "#microsoft.graph.allDevicesAssignmentTarget"
                        }
                        intent        = $App.AssignmentType
                        settings      = @{
                            "@odata.type"       = "#microsoft.graph.winGetAppAssignmentSettings"
                            notifications       = "hideAll"
                            installTimeSettings = $null
                            restartSettings     = $null
                        }
                    }
                    Write-Msg -Msg "Add assignment - 'All Devices'."
                }
                "AllUsers" {
                    $mobileAppAssignments += @{
                        "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                        target        = @{
                            "@odata.type" = "#microsoft.graph.allLicensedUsersAssignmentTarget"
                        }
                        intent        = $App.AssignmentType
                        settings      = @{
                            "@odata.type"       = "#microsoft.graph.winGetAppAssignmentSettings"
                            notifications       = "hideAll"
                            installTimeSettings = $null
                            restartSettings     = $null
                        }
                    }
                    Write-Msg -Msg "Add assignment - 'All Users'."
                }
                default {
                    Write-Msg -Msg "Assignment type not found or not supported."
                }
            }
        }

        # Add the assignments
        $assignBody = @{
            mobileAppAssignments = $mobileAppAssignments
        } | ConvertTo-Json -Depth 8 -ErrorAction "Stop"
        $params = @{
            Uri         = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/assign" -f $appDeploy.Id
            Method      = "POST"
            Headers     = $authHeader
            ContentType = "application/json"
            Body        = $assignBody
            ErrorAction = "Stop"
        }
        Invoke-RestMethod @params
        #endregion

        Write-Msg -Msg "Application import complete.`r`n"
    }
}

end {
    Write-Msg -Msg "Script complete."
}
