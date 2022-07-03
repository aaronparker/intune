<#
    .SYNOPSIS
        Pester tests
#>

# Variables
BeforeDiscovery {
    Import-Module (Join-Path -Path $PWD.Path -ChildPath "Test-XmlSchema.psm1")
    $SrcPath = Join-Path -Path $(Get-Item -Path $PWD.Path).Parent -ChildPath "templates"
    $Templates = Get-ChildItem -Path $SrcPath -Recurse -Include "*.*"
}

#region Tests
Describe -Name "Template file type tests" -ForEach $Templates {
    BeforeAll {
        $Template = $_
        $SchemaFile = Join-Path -Path $PWD.Path -ChildPath "SettingsLocationTemplate.xsd"
    }

    Context "Templates are XML files only" {
        It "<Template.Name> should be an .XML file" {
            #Write-Host "File: $($template.FullName)."
            [System.IO.Path]::GetExtension($Template.Name) -match ".xml$" | Should -BeTrue
        }
    }

    Context "Template XML format tests" {
        It "<Template.Name> should be in XML format" {
            try {
                [System.Xml.XmlDocument] $Content = Get-Content -Path $template.FullName -Raw -ErrorAction "SilentlyContinue"
            }
            catch {
                Write-Warning -Message "Failed to read $($template.Name)."
            }
            $Content | Should -BeOfType "System.Xml.XmlNode"
        }
        It "<Template.Name> should validate against the schema" {
            Write-Host "Schema: $SchemaFile."
            Write-Host "File: $($template.FullName)."
            Test-XmlSchema -XmlPath $template.FullName -SchemaPath $SchemaFile | Should -BeTrue
        }
    }
}
#endregion
