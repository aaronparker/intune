<#
    .SYNOPSIS
       XML Validation
       http://blogsprajeesh.blogspot.com/2015/06/powershell-xml-schema-validation.html
#>


function Test-XmlSchema {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.String] $XmlPath,
       
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path -Path $_ })]
        [System.String] $SchemaPath
    )

    $schemas = New-Object -TypeName "System.Xml.Schema.XmlSchemaSet"
    $schemas.CompilationSettings.EnableUpaCheck = $false
    $schema = Read-Schema $SchemaPath
    [void]($schemas.Add($schema))
    $schemas.Compile()
      
    try {
        [System.Xml.XmlDocument]$xmlData = Get-Content -Path $XmlPath
        $xmlData.Schemas = $schemas

        #Validate the schema. This will fail if is invalid schema
        $xmlData.Validate($null)
        return $true
    }
    catch [System.Xml.Schema.XmlSchemaValidationException] {
        return $false
    }
}

function Read-Schema {
    param($SchemaPath)
    try {
        $schemaItem = Get-Item -Path $SchemaPath
        $stream = $schemaItem.OpenRead()
        $schema = [Xml.Schema.XmlSchema]::Read($stream, $null)
        return $schema
    }
    catch {
        throw
    }
    finally {
        $stream.Close()
    }
}

Export-ModuleMember -Function Test-XmlSchema
