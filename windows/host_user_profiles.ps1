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
    $ErrorDetails += "LINEDETAIL: $($ErrorRecord.InvocationInfo.Line)"
    $ErrorDetails += "STATEMENT: $($ErrorRecord.InvocationInfo.Statement)"
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
. "$PSScriptRoot\scripts\utils_pshelper.ps1"
#if (test-path -path "$PSScriptRoot\scripts\$($env:USERNAME.ToLower()).ps1") {. "$PSScriptRoot\scripts\$($env:USERNAME.ToLower()).ps1"}

### Profiles

$init__winai__sysadmin = @{
    100 = { Set-StaticIpAddress -IpAddress "192.168.8.71" -IpSubnetMask "24" -IpGateway "192.168.8.1" }
    120 = { Set-DnsServerAddresses -DNSServers "192.168.7.50, 8.8.8.8" }
    140 = { Set-RdpOn }
    160 = { New-LocalSmbShare -DirPath "C:\xfer" -ShareName "xfer" }
    190 = { Set-AutoLogonCountFix }
    300 = { Set-InitialWingetEnvironment }
    301 = { Install-WingetApp -Id git.git -CustomArgs "--scope machine" }
    302 = { Install-WingetApp -Id Microsoft.PowerShell -CustomArgs "--source winget" }
    800 = { powershell.exe -executionpolicy bypass -file $env:AUTOWINPATH\winauto.ps1 -action trigger ; powershell.exe -executionpolicy bypass -command "Start-Sleep -Seconds 10" }
    900 = { Restart-Computer -Force }
}

$winai__sysadmin = @{
    100 = { if (!(Test-IsAdmin)) { Throw "Must run with elevated privs" } }
    110 = { Set-LocalUserEnableAndPassword -UserName "sysadmin" }
    200 = { New-LocalUserWithRandomPassword -UserName "ptimme01" -UserDescription "Paul Timmerman" }
    201 = { Set-LocalUserEnableAndPassword -UserName "ptimme01" }
    210 = { Add-LocalUserRdpGroup -UserName "ptimme01" }
    300 = { Install-WingetApp -Id microsoft.visualstudiocode -CustomArgs "--override ""/VERYSILENT /SP- /MERGETASKS='!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\'""" }
}

$winai__ptimme01 = @{
    220 = { Add-InitialGitConfig -UserName "ptimme01" -UserEmail "ptimme01@outlook.com" }
    300 = { Install-WingetApp -Id microsoft.visualstudiocode -CustomArgs "--override ""/VERYSILENT /SP- /MERGETASKS='!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\'""" }
    370 = { Install-WingetApp -Id Microsoft.VisualStudio.2022.Community -CustomArgs "--custom ""--add Microsoft.VisualStudio.Workload.NativeDesktop;includeRecommended""" }
    380 = { Install-WingetApp -Id Anaconda.Miniconda3 ; Set-Location -Path C:\Users\$env:username\miniconda3\condabin; ./conda init }
    600 = { Set-WindowsSystemAndAppDarkMode ; Set-WindowsFileExplorerHideFileExtensions -HideFileNameExtensions $false ; Set-WindowsFileExplorerShowHiddenItems -ShowHiddenItems $true }
}

$init__windev__sysadmin = @{
    100 = { Set-StaticIpAddress -IpAddress "192.168.8.70" -IpSubnetMask "24" -IpGateway "192.168.8.1" }
    120 = { Set-DnsServerAddresses -DNSServers "192.168.7.50, 8.8.8.8" }
    140 = { Set-RdpOn }
    160 = { New-LocalSmbShare -DirPath "C:\xfer" -ShareName "xfer" }
    190 = { Set-AutoLogonCountFix }
    220 = { Set-VirtualizationFeaturesAll }
    240 = { Install-Wsl }
    300 = { Set-InitialWingetEnvironment }
    301 = { Install-WingetApp -Id git.git -CustomArgs "--scope machine" }
    302 = { Install-WingetApp -Id Microsoft.PowerShell -CustomArgs "--source winget" }
    800 = { powershell.exe -executionpolicy bypass -file $env:AUTOWINPATH\winauto.ps1 -action trigger ; powershell.exe -executionpolicy bypass -command "Start-Sleep -Seconds 10" }
    900 = { Restart-Computer -Force }
}

$windev__sysadmin = @{
    100 = { if (!(Test-IsAdmin)) { Throw "Must run with elevated privs" } }
    110 = { Set-LocalUserEnableAndPassword -UserName "sysadmin" }
    200 = { New-LocalUserWithRandomPassword -UserName "ptimme01" -UserDescription "Paul Timmerman" }
    201 = { Set-LocalUserEnableAndPassword -UserName "ptimme01" }
    210 = { Add-LocalUserRdpGroup -UserName "ptimme01" }
    300 = { Install-WingetApp -Id microsoft.visualstudiocode -CustomArgs "--override ""/VERYSILENT /SP- /MERGETASKS='!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\'""" }
    
}

$windev__ptimme01 = @{
    220 = { Add-InitialGitConfig -UserName "ptimme01" -UserEmail "ptimme01@outlook.com" }
    300 = { Install-WingetApp -Id microsoft.visualstudiocode -CustomArgs "--override ""/VERYSILENT /SP- /MERGETASKS='!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\'""" }
    340 = { Install-WslDistribution -DistroName "Ubuntu-24.04" -Name main }
    345 = { Copy-GitRepo -GitRepoUrl "https://github.com/cymcore/cymdesk.git" -DestinationPath "C:\xfer\cymdesk" }
    350 = { Set-WslInstanceConfiguration -Name main -UserName ptimme01 -InstanceCymdeskPath "/mnt/c/xfer/cymdesk" }
    380 = { Install-WingetApp -Id Anaconda.Miniconda3 ; Set-Location -Path C:\Users\$env:username\miniconda3\condabin; ./conda init }
    600 = { Set-WindowsSystemAndAppDarkMode ; Set-WindowsFileExplorerHideFileExtensions -HideFileNameExtensions $false ; Set-WindowsFileExplorerShowHiddenItems -ShowHiddenItems $true }
}

$north__ptimme01 = @{
    220 = { Add-InitialGitConfig -UserName "ptimme01" -UserEmail "ptimme01@outlook.com" }
    300 = { Install-WingetApp -Id microsoft.visualstudiocode -CustomArgs "--override ""/VERYSILENT /SP- /MERGETASKS='!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath\'""" }
    330 = { Install-WingetApp -Id Microsoft.DotNet.SDK.8 }
    331 = { Install-WingetApp -Id Microsoft.DotNet.SDK.7 }
    340 = { Install-WslDistribution -DistroName "Ubuntu-24.04" -Name main }
    345 = { Copy-GitRepo -GitRepoUrl "https://github.com/cymcore/cymdesk.git" -DestinationPath "C:\xfer\cymdesk" }
    350 = { Set-WslInstanceConfiguration -Name main -UserName ptimme01 -InstanceCymdeskPath "/mnt/c/xfer/cymdesk" }
    600 = { Set-WindowsSystemAndAppDarkMode ; Set-WindowsFileExplorerHideFileExtensions -HideFileNameExtensions $false ; Set-WindowsFileExplorerShowHiddenItems -ShowHiddenItems $true }
}

### Set HostUserProfile (depends on if called with -Init)
if ($Init) {
    $HostUserProfile = get-variable -name "init__$($env:COMPUTERNAME.ToLower())__$($env:USERNAME.ToLower())" -ErrorAction SilentlyContinue -ValueOnly
}
else {
    $HostUserProfile = get-variable -name "$($env:COMPUTERNAME.ToLower())__$($env:USERNAME.ToLower())" -ErrorAction SilentlyContinue -ValueOnly
}

### Run functions
if ($null -ne $HostUserProfile -and $HostUserProfile -is [hashtable]) {
    foreach ($script in $HostUserProfile.GetEnumerator() | Sort-Object Key) {
        & $script.Value   
    }
}

