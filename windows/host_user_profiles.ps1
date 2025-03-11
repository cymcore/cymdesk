param (
    [bool]$Init = $false
)

### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Custom

### Source scripts
. "$PSScriptRoot\scripts\admin_functions.ps1"
. "$PSScriptRoot\scripts\user_functions.ps1"
#if (test-path -path "$PSScriptRoot\scripts\$($env:USERNAME.ToLower()).ps1") {. "$PSScriptRoot\scripts\$($env:USERNAME.ToLower()).ps1"}

### Profiles

$init__windev__sysadmin = @{
    100 = { Set-StaticIpAddress -IpAddress "192.168.8.70" -IpSubnetMask "24" -IpGateway "192.168.8.1" }
    120 = { Set-DnsServerAddresses -DNSServers "192.168.7.50, 8.8.8.8" }
    140 = { Set-RdpOn }
    160 = { New-LocalSmbShare -DirPath "C:\xfer" -ShareName "xfer" }
    190 = { Set-AutoLogonCountFix }
    220 = { Set-VirtualizationFeaturesAll }
    240 = { Install-Wsl -DistroName "Ubuntu-24.04" }
    900 = { Restart-Computer -Force }
}

$windev__sysadmin = @{
    100 = { Set-LocalUserEnableAndPassword -UserName "sysadmin" }
    200 = { New-LocalUserWithRandomPassword -UserName "ptimme01" -UserDescription "Paul Timmerman" }
    201 = { Set-LocalUserEnableAndPassword -UserName "ptimme01" }
}




### Set HostUserProfile (depends on if called with -Init)
if ($Init) {
    $HostUserProfile = get-variable -name "init__$($env:COMPUTERNAME.ToLower())__$($env:USERNAME.ToLower())" -ErrorAction SilentlyContinue -ValueOnly
}
else {
    $HostUserProfile = (get-variable -name "$($env:COMPUTERNAME.ToLower())__$($env:USERNAME.ToLower())" -ErrorAction SilentlyContinue).Value
}

### Run functions
if ($HostUserProfile.GetType().Name -eq "Hashtable") {
    foreach ($script in $HostUserProfile.GetEnumerator() | Sort-Object Key) {
        try{
            & $script.Value
        }
        catch {
            Write-output "Error in $($script.Key): $_" -ForegroundColor Red > c:\cymlogs\host_user_profiles.ps1.error
        }
    }

}


