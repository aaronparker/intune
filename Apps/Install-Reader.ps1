# Adobe Acrobat Reader DC
Start-Process -FilePath AcroRdrDC2001220048_en_US.exe -ArgumentList '-sfx_nu /sALL /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1' -Wait
Start-Process -FilePath 'C:\WINDOWS\System32\msiexec.exe' -ArgumentList '/update AcroRdrDCUpd2001220048.msp /quiet /qn' -Wait
