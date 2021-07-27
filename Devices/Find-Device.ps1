<#
    Find an enrolled device location via Microsoft Intune / Graph
    Original script: https://github.com/damienvanrobaeys/Intune_Scripts/blob/main/Locate%20device/Invoke_LocateDevice.ps1
#>
[CmdletBinding()]
param(
    [System.String] $DeviceName,
    [System.Management.Automation.SwitchParameter] $LastLocation,		
    [System.Management.Automation.SwitchParameter] $ShowMap,
    [System.Management.Automation.SwitchParameter] $Address	
)

$VerbosePreference = "Continue"
Write-Verbose -Message "Device name to locate is: $DeviceName"
Write-Verbose -Message "Looking for the device ID..."

try {
    $GetDevice = Get-IntuneManagedDevice | Get-MSGraphAllPages | Where-Object { $_.deviceName -like "$DeviceName" }
}
catch {
    Throw $_
}
If ($Null -eq $GetDevice) {
    Write-Error -Message "Cannot find device: $DeviceName."
}
Else {
    Write-Verbose -Message "Device ID is: $($GetDevice.ID)."

    $UrlLocation = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($GetDevice.ID)"
    $UrlLocateAction = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($GetDevice.ID)/locateDevice"

    If ($LastLocation) {
        try {
            $params = @{
                Url        = $UrlLocation
                HttpMethod = "GET"
            }
            $CheckLocation = (Invoke-MSGraphRequest @params).deviceActionResults.deviceLocation	
        }
        catch {
            Throw $_
        }

        If ($Null -ne $CheckLocation) {
            Write-Verbose -Message "Last check date is: $($CheckLocation.lastCollectedDateTime)."
        }	
        Else {
            Write-Warning -Message "Location for device is empty: $DeviceName."
        }
    }
    Else {
        try {
            $params = @{
                Url        = $UrlLocateAction
                HttpMethod = "POST"
            }
            Invoke-MSGraphRequest @params
        }
        catch {
            Throw $_
        }
        
        Do {
            try {
                $params = @{
                    Url        = $UrlLocation
                    HttpMethod = "GET"
                }
                $CheckLocation = (Invoke-MSGraphRequest @params).deviceActionResults.deviceLocation	
            }
            catch {
                Throw $_
            }
            
            If ($Null -eq $CheckLocation) {
                Write-Verbose -Message "Locating the device..."
                Start-Sleep 5
            }

        } Until ($Null -ne $CheckLocation)
    }

    If ($Null -ne $CheckLocation) {

        If ($PSBoundParameters.ContainsKey("ShowMap")) {
            Start-Process "https://www.google.com/maps?q=$($CheckLocation.latitude),$($CheckLocation.longitude)"
        }
        
        If ($PSBoundParameters.ContainsKey("Address")) {
            $Latitude = ($CheckLocation.latitude.ToString()).replace(",", ".")
            $Longitude = ($CheckLocation.longitude.ToString()).replace(",", ".")
            $Location = "https://geocode.xyz/$($Latitude),$($Longitude)?geoit=json"

            try {
                $params = @{
                    Uri             = $Location
                    UseBasicParsing = $true
                }
                Invoke-RestMethod @params
            }
            catch {
                Write-Warning -Message "Error while getting location address"
            }
        }

        If (!($ShowMap) -and !($Address)) {
            $CheckLocation
        }
    }
}
