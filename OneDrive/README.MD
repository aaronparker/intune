# OneDrive Configuration Scripts

Scripts for configuring the OneDrive client via PowerShell scripts deployed to Windows 10 with Microsoft Intune.

* _Install-OneDrivePerMachine.ps1_ - downloads and installs the OneDrive sync client in per-machine mode. Currently downloads and installs the preview version of the OneDrive client.
* _OneDrive-EnableADAL.ps1_ - must be deployed in the user's context by selecting 'Run this script using the logged on credentails'.
* _OneDrive-SilentAccountConfig.ps1_ - must run in the system context

For more information on configuring the OneDrive client see this article: [Use Group Policy to control OneDrive sync client settings](https://support.office.com/en-us/article/Use-Group-Policy-to-control-OneDrive-sync-client-settings-0ecb2cf5-8882-42b3-a6e9-be6bda30899c)
