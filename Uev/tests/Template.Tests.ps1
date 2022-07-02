<#
    .SYNOPSIS
        Pester tests
#>

# Variables
$srcPath = Join-Path $projectRoot "templates"
$templates = Get-ChildItem -Path $srcPath -Recurse -Include *.*

#region Tests
Describe "Template file type tests" {
    ForEach ($template in $templates) {
        It "$($template.Name) should be an .XML file" {
            [IO.Path]::GetExtension($template.Name) -match ".xml" | Should -Be $True
        }
    }
}

Describe "Template XML format tests" {
    ForEach ($template in $templates) {
        It "$($template.Name) should be in XML format" {
            Try {
                [xml] $content = Get-Content -Path $template.FullName -Raw -ErrorAction SilentlyContinue
            }
            Catch {
                Write-Warning "Failed to read $($template.Name)."
            }
            $content | Should -BeOfType System.Xml.XmlNode
        }
        It "$($template.Name) should validate against the schema" {
            Test-XmlSchema -XmlPath $template.FullName -SchemaPath $schema | Should -Be $True
        }
    }
}
#endregion
