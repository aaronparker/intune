# Find package identifiers
osascript -e 'id of app "Microsoft OneDrive"'

# Convert plist to mobileConfig
~/Temp/mcxToProfile.py --plist ~/Projects/Intune-Scripts/Apps/com.microsoft.Edge.plist --identifier com.Microsoft.Edge
