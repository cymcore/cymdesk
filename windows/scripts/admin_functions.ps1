### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Custom

Function New-LocalUserWithRandomPassword {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$UserDescription
    )

    $Password = Get-Random -Minimum 100000000000 -Maximum 999999999999
    $SecureStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    new-localuser -Description $UserDescription -PasswordNeverExpires -Password $SecureStringPassword -Name $UserName
    Disable-LocalUser -Name $UserName
    Add-LocalGroupMember -Group Users -Member $UserName
}

Function Set-StaticIpAddress {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IpAddress,
        [Parameter(Mandatory = $true)]
        [string]$IpSubnetMask,
        [Parameter(Mandatory = $true)]
        [string]$IpGateway
    )

    # -Dhcp Disabled parameter in Set-NetIPInterface does not work on a disconnected interface
    $SingleNetInterfaceIndex = (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "Ipv4" -and $_.ifIndex -ne 1 }).ifIndex
    Set-NetIPInterface -InterfaceIndex $SingleNetInterfaceIndex -Dhcp Disabled
    Remove-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    Remove-NetRoute -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    New-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -IPAddress $IpAddress -PrefixLength $IpSubnetMask -DefaultGateway $IpGateway
}

Function Set-DnsServerAddresses {
    param (
        [Parameter(Mandatory = $true)]
        [array]$DNSServers
    
    )
    Set-DnsClientServerAddress -InterfaceIndex  $SingleNetInterfaceIndex -ServerAddresses $DNSServers 
}

Function Set-VirtualizationFeaturesAll {
    Enable-WindowsOptionalFeature -FeatureName "VirtualMachinePlatform" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "HypervisorPlatform" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "Microsoft-Hyper-V" -All -Online -NoRestart
}

Function Set-AutoLogonCountFix {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $regValue = "AutoLogonCount"
    $newValue = 0
    Set-ItemProperty -Path $regPath -Name $regValue -Value $newValue -Type DWORD -Force
}

Function New-LocalSmbShare {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirPath,
        [Parameter(Mandatory = $true)]
        [string]$ShareName
    )
    if (!(Test-Path -Path $DirPath)) { New-Item -Path $DirPath -ItemType Directory }
    New-SmbShare -Path $DirPath -Name $ShareName -FullAccess Everyone
    Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"
}

Function Set-RdpOn {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

Function Install-Wsl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    wsl.exe --install -d $DistroName
}

Function Add-LocalUserRdpGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName

    )

    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $UserName
}

function Set-LocalUserEnableAndPassword {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )
    Enable-LocalUser -Name $UserName
    $securePassword = Read-Host -AsSecureString -Prompt "Enter $UserName password"
    Set-LocalUser -Name $UserName -Password $securePassword 
}