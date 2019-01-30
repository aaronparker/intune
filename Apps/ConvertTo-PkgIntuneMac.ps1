# Covert Firefox into PKG and then INTUNEMAC
$scratch = "/Users/aaron/Projects/macOS-Apps"

#region Firefox
# Variables
$dmg = "/Users/aaron/Downloads/Firefox 64.0.2.dmg"
$vol = "Firefox"
$version = "64.0.2"
$identifier = "org.mozilla.firefox"
$output = "$stratch/Firefox.pkg"

# Convert the DMG into PKG
hdiutil attach "$dmg"
pkgbuild --root "/Volumes/$vol" --version "$version" --identifier "$identifier" --install-location "/Applications" "$output"
hdiutil detach "/Volumes/$vol"

# Convert the PKG to INTUNEMAC
$pkg = "/Users/aaron/Projects/macOS-Apps/Firefox.pkg"
$output = "/Users/aaron/Projects/macOS-Apps"
~/bin/IntuneAppUtil -c "$pkg" -o "$scratch" -v

# A powerful, new engine that’s built for rapidfire performance. Better, faster page loading that uses less computer memory. Gorgeous design and smart features for intelligent browsing.
# https://www.mozilla.org/en-US/firefox/
# https://www.mozilla.org/en-US/privacy/websites/
#endregion


#region Chrome
$uri = "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
$dmg = Join-path $scratch "GoogleChrome.dmg"
$vol = "Google Chrome"
$version = "72.0.3626.81"
$identifier = "com.google.chrome"
$output = "$scratch/Chrome.pkg"

# Download Chrome
Invoke-WebRequest -Uri $uri -OutFile $dmg

# Convert the DMG into PKG
hdiutil attach "$dmg"
pkgbuild --root "/Volumes/$vol" --version "$version" --identifier "$identifier" --install-location "/Applications" "$output"
hdiutil detach "/Volumes/$vol"

# Convert the PKG to INTUNEMAC
$pkg = "$scratch/Chrome.pkg"
~/bin/IntuneAppUtil -c "$pkg" -o "$scratch" -v
#endregion