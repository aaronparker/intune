function Get-GeoCoordinate {
    # Source: https://github.com/MSEndpointMgr/Intune/tree/master/Autopilot

    # Construct return value object
    $Coordinates = [PSCustomObject]@{
        Latitude  = $null
        Longitude = $null
    }

    try {
        Add-Type -AssemblyName "System.Device"
        $GeoCoordinateWatcher = New-Object -TypeName "System.Device.Location.GeoCoordinateWatcher"
    }
    catch {
        throw $_
    }

    # Wait until watcher resolves current location coordinates
    $GeoCoordinateWatcher.Start()
    $GeoCounter = 0
    while (($GeoCoordinateWatcher.Status -notlike "Ready") -and ($GeoCoordinateWatcher.Permission -notlike "Denied") -and ($GeoCounter -le 60)) {
        Start-Sleep -Seconds 1
        $GeoCounter++
    }

    try {
        if ($GeoCoordinateWatcher.Permission -like "Denied") {
            # Break operation and return empty object since permission was denied
            return $Coordinates
        }
        else {
            # Set coordinates for return value
            $Coordinates.Latitude = ($GeoCoordinateWatcher.Position.Location.Latitude).ToString().Replace(",", ".")
            $Coordinates.Longitude = ($GeoCoordinateWatcher.Position.Location.Longitude).ToString().Replace(",", ".")
            # Handle return value
            return $Coordinates
        }
    }
    catch {
        throw $_
    }
    finally {
        # Stop and dispose of the GeCoordinateWatcher object
        $GeoCoordinateWatcher.Stop()
        $GeoCoordinateWatcher.Dispose()
    }
}
