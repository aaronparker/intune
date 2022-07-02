<#
    .SYNOPSIS
       XML Validation
       http://blogsprajeesh.blogspot.com/2015/06/powershell-xml-schema-validation.html
#>


function Test-XmlSchema {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [String] $XmlPath,
       
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Test-Path $_ })]
        [String] $SchemaPath
    )

    $schemas = New-Object -TypeName System.Xml.Schema.XmlSchemaSet
    $schemas.CompilationSettings.EnableUpaCheck = $false
    $schema = Read-Schema $SchemaPath
    [void]($schemas.Add($schema))
    $schemas.Compile()
      
    try {
        [xml]$xmlData = Get-Content $XmlPath
        $xmlData.Schemas = $schemas

        #Validate the schema. This will fail if is invalid schema
        $xmlData.Validate($null)
        return $true
    }
    catch [System.Xml.Schema.XmlSchemaValidationException] {
        return $false
    }
}

Function Read-Schema {
    param($SchemaPath)
    try {
        $schemaItem = Get-Item $SchemaPath
        $stream = $schemaItem.OpenRead()
        $schema = [Xml.Schema.XmlSchema]::Read($stream, $null)
        return $schema
    }
    catch {
        throw
    }
    finally {
        if ($stream) {
            $stream.Close()
        }
    }
}

Export-ModuleMember -Function Test-XmlSchema
