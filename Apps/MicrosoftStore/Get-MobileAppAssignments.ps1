<#
    .SYNOPSIS
        Get mobile app assignments

    .NOTES

#>
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)]
    [System.Object] $Apps,

    [Parameter()]
    [System.String] $AuthFile = "$PSScriptRoot\auth.json"
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
}

process {
    foreach ($App in $Apps) {
        Write-Msg -Msg "Get assignments for application: '$($App.DisplayName)'."
        $params = @{
            Uri         = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.id)/assignments"
            Method      = "GET"
            Headers     = $authHeader
            ErrorAction = "Stop"
        }
        $Assignments = Invoke-RestMethod @params
        $App | Add-Member -MemberType "NoteProperty" -Name "Assignments" -Value $Assignments.value -Force
        $App | ConvertTo-Json -Depth 8
    }
}
