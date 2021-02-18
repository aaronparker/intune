$Binary = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
$FileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Binary).FileVersion
$FileVersion = $FileVersion.Trim()
If ("21.001.20135" -eq $FileVersion) {
    #Write the version to STDOUT by default
    $FileVersion
    Exit 0
}
Else {
    #Exit with non-zero failure code
    Exit 1
}
