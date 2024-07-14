Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

public enum DSREG_JOIN_TYPE {
    DSREG_UNKNOWN_JOIN = 0,
    DSREG_DEVICE_JOIN = 1,
    DSREG_WORKPLACE_JOIN = 2
}

[StructLayout(LayoutKind.Sequential)]
public struct DSREG_USER_INFO {
    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszUserEmail;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszUserKeyId;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszUserKeyName;
}

[StructLayout(LayoutKind.Sequential)]
public struct DSREG_JOIN_INFO {
    public DSREG_JOIN_TYPE joinType;
    public IntPtr pJoinCertificate;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszDeviceId;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszIdpDomain;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszTenantId;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszJoinUserEmail;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszTenantDisplayName;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszMdmEnrollmentUrl;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszMdmTermsOfUseUrl;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszMdmComplianceUrl;

    [MarshalAs(UnmanagedType.LPWStr)]
    public string pszUserSettingSyncUrl;

    public IntPtr pUserInfo;
}

public class dsreg {
    [DllImport("netapi32.dll", CharSet = CharSet.Unicode)]
    public static extern int NetGetAadJoinInformation(
        [MarshalAs(UnmanagedType.LPWStr)] string pcszTenantId,
        out IntPtr ppJoinInfo
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode)]
    public static extern void NetFreeAadJoinInformation(IntPtr pJoinInfo);
}
'@

function Get-AadJoinInformation {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TenantId
    )

    $ppJoinInfo = [IntPtr]::Zero

    $result = [dsreg]::NetGetAadJoinInformation($TenantId, [ref]$ppJoinInfo)
    if ($result -eq 0) {
        # Marshal the IntPtr to DSREG_JOIN_INFO structure
        $joinInfoStruct = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ppJoinInfo, [type][DSREG_JOIN_INFO])

        # Convert pJoinCertificate to X509Certificate2
        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($joinInfoStruct.pJoinCertificate)

        # Manually marshal pUserInfo to DSREG_USER_INFO if not IntPtr.Zero
        $userInfoStruct = $null
        if ($joinInfoStruct.pUserInfo -ne [IntPtr]::Zero) {
            $userInfoStruct = [System.Runtime.InteropServices.Marshal]::PtrToStructure($joinInfoStruct.pUserInfo, [type][DSREG_USER_INFO])
        }

        # Free the memory using NetFreeAadJoinInformation
        [dsreg]::NetFreeAadJoinInformation($ppJoinInfo)

        # Create a PSObject with friendly names
        $resultObject = [PSCustomObject]@{
            JoinType           = $joinInfoStruct.joinType
            Certificate         = $certificate
            DeviceId           = $joinInfoStruct.pszDeviceId
            IdpDomain          = $joinInfoStruct.pszIdpDomain
            TenantId           = $joinInfoStruct.pszTenantId
            JoinUserEmail      = $joinInfoStruct.pszJoinUserEmail
            TenantDisplayName  = $joinInfoStruct.pszTenantDisplayName
            MdmEnrollmentUrl   = $joinInfoStruct.pszMdmEnrollmentUrl
            MdmTermsOfUseUrl   = $joinInfoStruct.pszMdmTermsOfUseUrl
            MdmComplianceUrl   = $joinInfoStruct.pszMdmComplianceUrl
            UserSettingSyncUrl = $joinInfoStruct.pszUserSettingSyncUrl
            UserEmail          = $userInfoStruct.pszUserEmail
            UserKeyId          = $userInfoStruct.pszUserKeyId
            UserKeyName        = $userInfoStruct.pszUserKeyName
        }

        return $resultObject
    }
    else {
        # If failed to get AAD join information, return $null
        return $null
    }
}

# Call the function with or without the TenantId
# Example calls:
# $result = Get-AadJoinInformation -TenantId "YourTenantIdHere"
# $result = Get-AadJoinInformation

# Access the returned object's properties like: $result.DeviceId or $result.UserEmail