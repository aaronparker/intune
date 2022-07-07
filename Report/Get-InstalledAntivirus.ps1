# https://www.nextofwindows.com/how-to-tell-what-antivirus-software-installed-on-a-remote-windows-computer
# Get installed antivirus product

# define bit flags
[Flags()] enum ProductState {
    Off = 0x0000
    On = 0x1000
    Snoozed = 0x2000
    Expired = 0x3000
}

[Flags()] enum SignatureStatus {
    UpToDate = 0x00
    OutOfDate = 0x10
}

[Flags()] enum ProductOwner {
    NonMs = 0x000
    Windows = 0x100
}

# define bit masks
[Flags()] enum ProductFlags {
    SignatureStatus = 0x00F0
    ProductOwner = 0x0F00
    ProductState = 0xF000
}

# get bits
$infos = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "AntiVirusProduct" -ComputerName $computer
ForEach ($info in $infos) {
    [System.UInt32]$state = $info.productState

    # decode bit flags by masking the relevant bits, then converting
    [PSCustomObject]@{
        ProductName     = $info.DisplayName
        ProductState    = [ProductState]($state -band [ProductFlags]::ProductState)
        SignatureStatus = [SignatureStatus]($state -band [ProductFlags]::SignatureStatus)
        Owner           = [ProductOwner]($state -band [ProductFlags]::ProductOwner)
    }
}
