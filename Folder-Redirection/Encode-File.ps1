<#PSScriptInfo
    .VERSION 1.0
    .GUID 3ea6c490-deb5-476d-9809-69bef723b820
    .AUTHOR Aaron Parker, @stealthpuppy
    .COMPANYNAME stealthpuppy
    .COPYRIGHT Aaron Parker, https://stealthpuppy.com
    .TAGS Encode Base64
    .LICENSEURI https://github.com/aaronparker/Intune/blob/master/LICENSE
    .PROJECTURI https://github.com/aaronparker/Intune
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
    .PRIVATEDATA
#>
<#
    .DESCRIPTION
        Encode a file in Base64.
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $InputFile,

    [Parameter()]
    [System.String] $OutputFile
)

Function Encode-Text {
    [CmdletBinding()]
    Param (
        [Parameter()]
        $Text
    )

    # Covert to Base64
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)
    $EncodedText = [Convert]::ToBase64String($Bytes)

    # Return the output to the pipeline
    Write-Output $EncodedText
}

# Read the input file
$inputFileContent = Get-Content -Path $InputFile

# Convert file to encoded text and output to a file
Encode-Text -Text $inputFileContent | Out-File -FilePath $OutputFile
