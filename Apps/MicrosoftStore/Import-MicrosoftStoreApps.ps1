<#
    .SYNOPSIS
        Import Microsoft Store apps into Intune with an icon

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
    [System.String] $AppList = "$PSScriptRoot\StoreApps.csv"
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
    $Secrets = Get-Content -Path $AuthFile | ConvertFrom-Json

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

    # Read apps list
    Write-Msg -Msg "Import applications list from '$AppList'.`r`n"
    $Apps = Import-Csv -Path $AppList -ErrorAction "Stop"
}

process {
    foreach ($App in $Apps) {
        Write-Msg -Msg "Importing application: '$($App.DisplayName)'."

        #region Search for the app
        $body = @{
            Query = @{
                KeyWord   = $App.DisplayName
                MatchType = "Substring"
            }
        } | ConvertTo-Json -ErrorAction "Stop"
        $params = @{
            Uri         = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/manifestSearch"
            Method      = "POST"
            ContentType = "application/json"
            Body        = $body
            ErrorAction = "Stop"
        }
        Write-Msg -Msg "Perform application search in the Microsoft Store."
        $appSearch = Invoke-RestMethod @params
        $exactApp = $appSearch.Data | Where-Object { $_.PackageName -eq $App.DisplayName }
        #endregion

        #region Get details for the app
        Write-Msg -Msg "Perform application manifest search in the Microsoft Store."
        $appUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/{0}" -f $exactApp.PackageIdentifier
        $app = Invoke-RestMethod -Uri $appUrl -Method "GET" -ErrorAction "Stop"
        $appInfo = $app.Data.Versions[-1].DefaultLocale
        $appInstaller = $app.Data.Versions[-1].Installers
        #endregion

        #region Get the icon for the app
        Write-Msg -Msg "Get the icon for this application."
        $imageUrl = "https://apps.microsoft.com/store/api/ProductsDetails/GetProductDetailsById/{0}?hl=en-US&gl=US" -f $exactApp.PackageIdentifier
        $image = Invoke-RestMethod -Uri $imageUrl -Method "GET" -ErrorAction "Stop"
        $base64Icon = [System.Convert]::ToBase64String((Invoke-WebRequest -Uri $image.IconUrl -ErrorAction "Stop").Content)
        #endregion

        #region Import the app into Intune
        $appBody = @{
            '@odata.type'         = "#microsoft.graph.winGetApp"
            description           = $appInfo.Description
            developer             = $appInfo.Publisher
            displayName           = $appInfo.packageName
            informationUrl        = $appInfo.PublisherSupportUrl
            largeIcon             = @{
                "@odata.type" = "#microsoft.graph.mimeContent"
                "type"        = "image/png"
                "value"       = $base64Icon
            }
            installExperience     = @{
                runAsAccount = $appInstaller[-1].scope
            }
            isFeatured            = $false
            packageIdentifier     = $app.Data.PackageIdentifier
            privacyInformationUrl = $appInfo.PrivacyUrl
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
        $appDeploy = Invoke-RestMethod @params
        #endregion

        #region Configure the app assignment
        switch ($App.AssignmentTarget) {
            "AllDevices" {
                $assignBody = @{
                    mobileAppAssignments = @(
                        @{
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
                    )
                } | ConvertTo-Json -Depth 8 -ErrorAction "Stop"
                Write-Msg -Msg "Add assignment - 'All Devices'."
            }
            "AllUsers" {
                $assignBody = @{
                    mobileAppAssignments = @(
                        @{
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
                    )
                } | ConvertTo-Json -Depth 8 -ErrorAction "Stop"
                Write-Msg -Msg "Add assignment - 'All Users'."
            }
            default {
                Write-Msg -Msg "Assignment type not found or not supported."
            }
        }

        # Add the assignment
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
