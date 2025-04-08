
### Source Files
. $PSScriptRoot\utils_pshelper.ps1

Function Test-IsAdmin {
    <#
                .SYNOPSIS
                    Short function to determine whether the logged-on user is an administrator.

                .EXAMPLE
                    Do you honestly need one?  There are no parameters!

                .OUTPUTS
                    $true if user is admin.
                    $false if user is not an admin.
            #>
    [CmdletBinding()]
    param()

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}

Function Test-IsDesktopPC {
    $isDesktopPC = $true
    if (Get-WmiObject -Class win32_systemenclosure | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14 }) {
        $isDesktopPC = $false
    }
    if (Get-WmiObject -Class win32_battery)
    { $isDesktopPC = $false }
    $isDesktopPC
}

Function Test-IsHyperVEnabled {
    if (Get-WindowsOptionalFeature -Online | Where-Object FeatureName -Like 'Microsoft-Hyper-V-All') {
        Return $true
    }
    Else {

        Return $false
    }
}

Function Test-IsWindows10 {

    $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
    
    if ($osVersion -match "Windows 10" -and $osVersion -notmatch "Server") {
        return $true
    }
    else {
        return $false
    }
}

Function Test-IsWindows11 {

    $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
    
    if ($osVersion -match "Windows 11" -and $osVersion -notmatch "Server") {
        return $true
    }
    else {
        return $false
    }
}

Function Get-WindowsEdition {
    $build = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build.editionid
}

Function Get-WindowsBuildNumber {
    $build = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object buildnumber
    $build
}
Function Mount-ISOReliable {
    param (
        [string]$SourcePath
    )
    $mountResult = Mount-DiskImage -ImagePath $SourcePath
    $delay = 0
    Do {
        if ($delay -gt 15) {
            Function Get-NewDriveLetter {
                $UsedDriveLetters = ((Get-Volume).DriveLetter) -join ""
                Do {
                    $DriveLetter = (65..90) | Get-Random | ForEach-Object { [char]$_ }
                }
                Until (!$UsedDriveLetters.Contains("$DriveLetter"))
                $DriveLetter
            }
            $DriveLetter = "$(Get-NewDriveLetter)" + ":"
            Get-WmiObject -Class Win32_volume | Where-Object { $_.Label -eq "CCCOMA_X64FRE_EN-US_DV9" } | Set-WmiInstance -Arguments @{DriveLetter = "$driveletter" }
        }
        Start-Sleep -s 1 
        $delay++
    }
    Until ($NULL -ne ($mountResult | Get-Volume).DriveLetter)
    ($mountResult | Get-Volume).DriveLetter
}