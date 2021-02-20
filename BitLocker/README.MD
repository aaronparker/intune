# BitLocker

NOTE: this script should no longer be required with Disk encryption policies in Intune and current Windows 10 versions.

This is a [Microsoft provided script](https://blogs.technet.microsoft.com/showmewindows/2018/01/18/how-to-enable-bitlocker-and-escrow-the-keys-to-azure-ad-when-using-autopilot-for-standard-users/) that attempts to enable BitLocker on the system drive and upload the recovery key to Azure AD. This allows non-HSTI devices to automatically encrypt drives.

Further reading: [http://www.scconfigmgr.com/2018/10/23/enabling-bitlocker-on-non-hsti-devices-with-intune/](http://www.scconfigmgr.com/2018/10/23/enabling-bitlocker-on-non-hsti-devices-with-intune/)
