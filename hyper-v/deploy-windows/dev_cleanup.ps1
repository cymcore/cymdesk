param (
    [Parameter(Mandatory = $true)]
    [string]$VmConfigDir
)

### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
. $PSScriptRoot\utils_hyperv.ps1

### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined Variables
$ConfigsDir = ($PSScriptRoot + "\vm_configs") 

### Derived Variables

### Run Checks
if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
if (!(Test-Path -Path $ConfigsDir)) { Throw "VmConfigsDir ($ConfigsDir) not found" }
if (!(Test-Path -Path ($ConfigsDir + "\" + $VmConfigDir))) { Throw "VmConfigDir ($VmConfigDir) not found" }
if (!(Test-Path -Path ($ConfigsDir + "\" + $VmConfigDir + "\" + "config.ps1"))) { Throw "Config file (config.ps1) not found" }

### Source Files
. ($ConfigsDir + "\" + $VmConfigDir + "\" + "config.ps1")

### Main
$vmName = $vm_config.VmName
$VmPath = $vm_config.VmPath
$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue

if ($vm) {
    $vmExists = $true
}
else {
    $vmExists = $false
}

if ($vmExists) {
    if ((Get-VM -Name $vmName).State -eq "Running") {
        Stop-VM -Name $vmName -Force
        Write-Host "VM '$vmName' has been turned off."
    }
    else {
        Write-Host "VM '$vmName' is not running."
    }

    Remove-VM -Name $vmName -Force
}

$VHDXPath = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")

if (Test-IsVhdxMounted -VHDXPath $VHDXPath) { Dismount-VHD -Path $VHDXPath }

$directoryPath = ($VmPath + $VmName)

if (Test-Path -Path $directoryPath) {
    Remove-Item -Path $directoryPath -Recurse -Force
    Write-Host "Directory '$directoryPath' has been deleted."
} else {
    Write-Host "Directory '$directoryPath' does not exist."
}

$mounted_images = (Get-WmiObject -Class Win32_CDROMDrive).drive
foreach ($drive in $mounted_images) {
    $driveLetter = $drive
    $deviceid = (Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveLetter -eq $driveLetter }).deviceid
    $trim = $deviceid.Substring(0, $deviceid.Length - 1)

    Dismount-DiskImage -DevicePath $trim

}