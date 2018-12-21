<# PSScriptInfo
    .NOTES
        Source: 21/02/2018
        http://thinkdeploy.blogspot.com/2018/02/setting-asset-tag-on-thinkpads-with-mdm.html
        
        10/11/2018
        Aaron Parker, @stealthpuppy
        - Add check for Win32_ComputerSystem.Manufacturer = LENOVO
        - Add logging; fix quotes; cleanup code; check download is successful; & more


    .DESCRIPTION
        This script is designed to hide Vantage features that may not be appropriate
        for enterprise customers.  Each feature is commented out beside each GUID in
        each array.
#>

# Start PowerShell as 64 bit process
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

# Transcript for logging
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile -NoClobber
$VerbosePreference = "Continue"

# Intune PowerShell scripts can only be targeted at user groups not device groups
# If the local device Manufacturer is 'LENOVO' make changes
If ((Get-CimInstance -ClassName "Win32_ComputerSystem").Manufacturer -eq "LENOVO") {

    # Variables
    $url = "https://download.lenovo.com/pccbbs/mobiles/giaw03ww.exe" # URL to WinAIA Utility
    $pkg = Split-Path $url -Leaf
    $tempDir = Join-Path (Join-Path $env:ProgramData "Lenovo") "Temp"
    $extractSwitch = "/VERYSILENT /DIR=$($tempDir) /EXTRACT=YES"

    # Asset data
    # These are sample values and should be changed.
    $ownerName = "stealthpuppy"
    $ownerData = "Ministry of Silly Walks"
    $ownerLocation = "Melbourne, VIC"
    # Variable for last 5 characters of Unique ID
    $uuid = ((Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID).SubString(30))

    # Create temp directory for utility and log output file 
    Write-Output "Creating Temp Directory"
    if ((Test-Path -Path $tempDir) -eq $false) {
        New-Item -Path $tempDir -ItemType Directory -Force
    }
 
    # Download utility via HTTPS
    Write-Output "Downloading WinAIA Utility"
    Start-BitsTransfer -Source $url -Destination "$tempdir\$pkg"
    If (Test-Path -Path "$tempdir\$pkg") {

        # Set location of WinAIA Package and extract contents
        Set-Location $tempDir
        Start-Process ".\$pkg" -ArgumentList $extractSwitch -Wait

        # Set Owner Data with WinAIA Utility
        Write-Output "Writing Asset Owner Information"
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set 'OWNERDATA.OWNERNAME=$($ownerName)'" -Wait
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set 'OWNERDATA.DEPARTMENT=$($ownerData)'" -Wait
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set 'OWNERDATA.LOCATION=$($ownerLocation)'" -Wait

        # Set Asset Number.  Available through WMI by querying the SMBIOSASSetTag field of the Win32_SystemEnclosure class
        Write-Output "Setting Asset Tag"
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -set 'USERASSETDATA.ASSET_NUMBER=$uuid'" -Wait

        # AIA Output file
        Write-Output "Outputting AIA Text File"
        Start-Process "$tempDir\WinAIA64.exe" -ArgumentList "-silent -output-file '$tempdir\aia_output.txt' -get OWNERDATA" -Wait

        # Remove Package
        Write-Output "Removing Package"
        Remove-Item -LiteralPath $tempDir\$pkg -Force
    }
    Else {
        Write-Output "Failed to download $url"
    }
}
Else {

    # Local device is not from Lenovo
    Write-Output "Local system is not a Lenovo device. Exiting."
}

Stop-Transcript
