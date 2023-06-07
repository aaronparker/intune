
$Source = Gci -Path "E:\projects\icons\icons\MicrosoftStore-Microsoft365.png" | Select-Object -ExpandProperty FullName

Add-Type -AssemblyName "System.Drawing"
$ImageFormat = "System.Drawing.Imaging.ImageFormat" -as [Type]
$Image = [Drawing.Image]::FromFile($Source)
    
# $image.Save($basedir, $imageFormat::jpeg) Don't save here!

# Create a new image
$NewImage = [System.Drawing.Bitmap]::new($Image.Width, $Image.Height)
$NewImage.SetResolution($Image.HorizontalResolution, $Image.VerticalResolution)


# Add graphics based on the new image
$Graphics = [System.Drawing.Graphics]::FromImage($NewImage)
$Colour = [System.Drawing.ColorTranslator]::FromHtml("#0078D4")
$Graphics.Clear([System.Drawing.Color]::$Colour.Name) # Set the color to white
$Graphics.Clear([System.Drawing.Color]::White) # Set the color to white
$Graphics.DrawImageUnscaled($Image, 0, 0) # Add the contents of $image

# Now save the $NewImage instead of $image
$NewImage.Save($BaseDir, $ImageFormat::Jpeg)

# Uncomment these two lines if you want to delete the png files:
# $image.Dispose()
# Remove-Item $Source