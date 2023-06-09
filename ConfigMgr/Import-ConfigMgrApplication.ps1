
[CmdletBinding(SupportsShouldProcess = $true, HelpURI = "https://vcredist.com/import-vcconfigmgrapplication/")]

param (
    [Parameter(Mandatory = $false)]
    [System.ObsoleteAttribute("This parameter is not longer supported. The Path property must be on the object passed to -VcList.")]
    [System.String] $Path,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [System.String] $CMPath,

    [Parameter(Mandatory = $true, Position = 3)]
    [ValidateScript( { if ($_ -match "^[a-zA-Z0-9]{3}$") { $true } else { throw "$_ is not a valid ConfigMgr site code." } })]
    [System.String] $SMSSiteCode,

    [Parameter(Mandatory = $false, Position = 4)]
    [ValidatePattern("^[a-zA-Z0-9]+$")]
    [System.String] $AppFolder = "",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $Silent,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter] $NoCopy,

    [Parameter(Mandatory = $false, Position = 5)]
    [ValidatePattern("^[a-zA-Z0-9]+$")]
    [System.String] $Publisher = "",

    [Parameter(Mandatory = $false, Position = 6)]
    [ValidatePattern("^[a-zA-Z0-9\+ ]+$")]
    [System.String] $Keyword = ""
)

begin {
    #region If the ConfigMgr console is installed, load the PowerShell module; Requires PowerShell module to be installed
    if (Test-Path -Path env:SMS_ADMIN_UI_PATH) {
        try {
            # Import the ConfigurationManager.psd1 module
            $params = @{
                Path        = $(Split-Path -Path $env:SMS_ADMIN_UI_PATH -Parent)
                Filter      = "ConfigurationManager.psd1"
                ErrorAction = "SilentlyContinue"
            }
            $ModuleFile = Get-ChildItem @params
            if (-not[System.String]::IsNullOrEmpty($ModuleFile)) {
                Write-Verbose -Message "Importing module: $($ModuleFile.FullName)"
                Import-Module -Name $ModuleFile.FullName -Verbose:$false
            }
            else {
                $Msg = "Could not load ConfigurationManager.psd1 from $(Split-Path -Path $env:SMS_ADMIN_UI_PATH -Parent). Please make sure that the Configuration Manager console is installed."
                throw [System.IO.FileNotFoundException]::New($Msg)
            }
        }
        catch {
            throw $_
        }
    }
    else {
        $Msg = "Cannot find environment variable SMS_ADMIN_UI_PATH. Is the ConfigMgr console and PowerShell module installed?"
        throw [System.Exception]::New($Msg)
    }
    #endregion

    #region Validate $CMPath
    if (Resolve-Path -Path $CMPath) {
        $CMPath = $CMPath.TrimEnd("\")

        # Create the folder for importing the Redistributables into
        if ($AppFolder.Length -gt 0) {
            $DestCmFolder = "$($SMSSiteCode):\Application\$($AppFolder)"
            if ($PSCmdlet.ShouldProcess($DestCmFolder, "Creating")) {
                Write-Verbose -Message "Creating: $DestCmFolder."
                New-Item -Path $DestCmFolder -ErrorAction "Continue" > $null
            }
        }
        else {
            Write-Verbose -Message "Importing into: $($SMSSiteCode):\Application."
            $DestCmFolder = "$($SMSSiteCode):\Application"
        }
    }
    else {
        $Msg = "Unable to confirm '$CMPath' exists. Please check that '$CMPath' is valid."
        throw [System.IO.DirectoryNotFoundException]::New($Msg)
    }
    #endregion
}

process {


        # Import as an application into ConfigMgr
        if ($PSCmdlet.ShouldProcess("'$($VcRedist.Name)' in $CMPath", "Import ConfigMgr app")) {

            # Create the ConfigMgr application with properties from the manifest
            if ((Get-Item -Path $DestCmFolder).PSDrive.Name -eq $SMSSiteCode) {
                if ($PSCmdlet.ShouldProcess($VcRedist.Name + " $($VcRedist.Architecture)", "Creating ConfigMgr application")) {

                    # Build paths
                    $SourceFolder = $(Split-Path -Path $VcRedist.Path -Parent)
                    $ContentLocation = [System.IO.Path]::Combine($CMPath, $VcRedist.Release, $VcRedist.Version, $VcRedist.Architecture)

                    #region Copy VcRedists to the network location. Use robocopy for robustness
                    if ($PSBoundParameters.Contains($NoCopy)) {
                        Write-Warning -Message "NoCopy specified, skipping copy to $ContentLocation. Ensure VcRedists exist in the target."
                    }
                    else {
                        if ($PSCmdlet.ShouldProcess("'$($VcRedist.Path)' to '$($ContentLocation)'", "Copy")) {
                            if (!(Test-Path -Path $ContentLocation)) {
                                New-Item -Path $ContentLocation -ItemType "Directory" -ErrorAction "Continue" > $null
                            }
                            try {
                                $invokeProcessParams = @{
                                    FilePath     = "$env:SystemRoot\System32\robocopy.exe"
                                    ArgumentList = "$(Split-Path -Path $VcRedist.Path -Leaf) `"$SourceFolder`" `"$ContentLocation`" /S /XJ /R:1 /W:1 /NP /NJH /NJS /NFL /NDL"
                                }
                                Invoke-Process @invokeProcessParams | Out-Null
                            }
                            catch [System.Exception] {
                                $Err = $_
                                $Target = Join-Path -Path $ContentLocation -ChildPath $(Split-Path -Path $VcRedist.Path -Leaf)
                                if (Test-Path -Path $Target) {
                                    Write-Verbose -Message "Copy successful: '$Target'."
                                }
                                else {
                                    Write-Warning -Message "Failed to copy Redistributables from '$($VcRedist.Path)' to '$ContentLocation'."
                                    throw $Err
                                }
                            }
                        }
                    }
                    #endregion

                    # Change to the SMS Application folder before importing the applications
                    try {
                        Write-Verbose -Message "Setting location to: $DestCmFolder"
                        Set-Location -Path $DestCmFolder -ErrorAction "Continue"
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to set location to: $DestCmFolder."
                        throw $_
                    }

                    try {
                        # Splat New-CMApplication parameters, add the application and move into the target folder
                        $ApplicationName = "Visual C++ Redistributable $($VcRedist.Release) $($VcRedist.Architecture) $($VcRedist.Version)"
                        $cmAppParams = @{
                            Name              = $ApplicationName
                            Description       = "$Publisher $ApplicationName imported by $($MyInvocation.MyCommand). https://vcredist.com"
                            SoftwareVersion   = $VcRedist.Version
                            LinkText          = $VcRedist.URL
                            Publisher         = $Publisher
                            Keyword           = $Keyword
                            ReleaseDate       = $(Get-Date -Format (([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat).ShortDatePattern))
                            PrivacyUrl        = "https://go.microsoft.com/fwlink/?LinkId=521839"
                            UserDocumentation = "https://visualstudio.microsoft.com/vs/support/"
                        }
                        $app = New-CMApplication @cmAppParams
                        if ($AppFolder) {
                            $app | Move-CMObject -FolderPath $DestCmFolder -ErrorAction "SilentlyContinue" > $null
                        }
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to create application $($VcRedist.Name) $($VcRedist.Architecture)."
                        throw $_
                    }
                    # Write app detail to the pipeline
                    Write-Output -InputObject $app
                }

                # Add a deployment type to the application
                if ($PSCmdlet.ShouldProcess($("$($VcRedist.Name) $($VcRedist.Architecture) $($VcRedist.Version)"), "Adding deployment type")) {

                    # Change to the SMS Application folder before importing the applications
                    try {
                        Write-Verbose -Message "Set location to: $DestCmFolder"
                        Set-Location -Path $DestCmFolder -ErrorAction "Continue"
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to set location to: $DestCmFolder."
                        throw $_
                    }

                    try {
                        # Create the detection method
                        $params = @{
                            Hive    = "LocalMachine"
                            Is64Bit = if ($VcRedist.UninstallKey -eq "64") { $true } else { $false }
                            KeyName = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($VcRedist.ProductCode)"
                        }
                        $detectionClause = New-CMDetectionClauseRegistryKey @params

                        # Splat Add-CMScriptDeploymentType parameters and add the application deployment type
                        $cmScriptParams = @{
                            ApplicationName          = $ApplicationName
                            InstallCommand           = "$(Split-Path -Path $VcRedist.Path -Leaf) $(if ($Silent) { $VcRedist.SilentInstall } else { $VcRedist.Install })"
                            ContentLocation          = $ContentLocation
                            AddDetectionClause       = $detectionClause
                            DeploymentTypeName       = "SCRIPT_$($VcRedist.Name)"
                            UserInteractionMode      = "Hidden"
                            UninstallCommand         = $VcRedist.SilentUninstall
                            LogonRequirementType     = "WhetherOrNotUserLoggedOn"
                            InstallationBehaviorType = "InstallForSystem"
                            Comment                  = "Generated by $($MyInvocation.MyCommand). https://vcredist.com"
                        }
                        Add-CMScriptDeploymentType @cmScriptParams > $null
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to add script deployment type."
                        throw $_
                    }
                }
            }
        }

}

end {
}
