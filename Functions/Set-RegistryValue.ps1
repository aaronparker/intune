function Set-RegistryValue {
    <#
        .SYNOPSIS
            Creates a registry value in a target key. Creates the target key if it does not exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $True)]
        [System.String] $Key,

        [Parameter(Mandatory = $True)]
        [System.String] $Value,

        [Parameter(Mandatory = $True)]
        $Data,

        [Parameter(Mandatory = $False)]
        [ValidateSet('Binary', 'ExpandString', 'String', 'Dword', 'MultiString', 'QWord')]
        [System.String] $Type = "String"
    )

    try {
        if (Test-Path -Path $Key -ErrorAction "SilentlyContinue") {
            Write-Verbose "Path exists: $Key"
        }
        else {
            Write-Verbose -Message "Does not exist: $Key."

            $folders = $Key -split "\\"
            $parent = $folders[0]
            Write-Verbose -Message "Parent is: $parent."

            foreach ($folder in ($folders | Where-Object { $_ -notlike "*:"})) {
                if ($PSCmdlet.ShouldProcess($Path, ("New-Item '{0}'" -f "$parent\$folder"))) {
                    New-Item -Path $parent -Name $folder -ErrorAction "SilentlyContinue" | Out-Null
                }
                $parent = "$parent\$folder"
                if (Test-Path -Path $parent -ErrorAction "SilentlyContinue") {
                    Write-Verbose -Message "Created $parent."
                }
            }
            Test-Path -Path $Key -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to create key $Key."
        break
    }
    finally {
        Write-Verbose -Message "Setting $Value in $Key."
        if ($PSCmdlet.ShouldProcess($Path, ("New-ItemProperty '{0}'" -f $Key))) {
            New-ItemProperty -Path $Key -Name $Value -Value $Data -PropertyType $Type -Force -ErrorAction "SilentlyContinue" | Out-Null
        }
    }

    $val = Get-Item -Path $Key
    if ($val.Property -contains $Value) {
        Write-Verbose "Write value success: $Value"
        Write-Output $True
    } else {
        Write-Verbose "Write value failed."
        Write-Output $False
    }
}
