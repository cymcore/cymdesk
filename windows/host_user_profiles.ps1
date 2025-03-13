param (
    [switch]$Init
)

### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

trap {
    Show-ErrorAndStackTrace -ErrorRecord $_
}

# Function to log detailed error information, including stack trace
Function Show-ErrorAndStackTrace {
    param ([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $ErrorGuid = [guid]::NewGuid()
    $ErrorDetails = @()
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $ErrorDetails += "ERROR_START_$ErrorGuid"
    $ErrorDetails += "ERRORMSG: $($ErrorRecord.Exception.Message)"
    $ErrorDetails += "SOURCE: $($ErrorRecord.InvocationInfo.ScriptName)"
    $ErrorDetails += "LINENUMBER: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
    $ErrorStackTrace = $ErrorRecord.ScriptStackTrace -split "`n"
    foreach ($ErrorLine in $ErrorStackTrace) {
        $ErrorDetails += "STACKTRACE: $ErrorLine"
    }
    $ErrorDetails += "ERROR_END_$ErrorGuid"
   
    foreach ($ErrorDetail in $ErrorDetails) {
        Write-Host("$TimeStamp - $ErrorDetail")
        if ($LogFile) {
            "$TimeStamp - $ErrorDetail" | Out-File -FilePath $LogFile -Append
        }
    }
}

### Defined variables
$LogFile = "c:\cymlogs\host_user_profiles.ps1.error"
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
    300 = { Install-WingetApp -Id git.git -CustomArgs "--scope machine" }
    800 = { powershell -executionpolicy bypass -file $env:AUTOWINPATH\winauto.ps1 -action trigger} 
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
            & $script.Value   
    }
}


