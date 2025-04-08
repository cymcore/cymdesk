
### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
Function Test-IsVhdxMounted {
    param (
        [string]$VHDXPath
    )

    $VhdObject = Get-VHD -Path $VHDXPath 
 
    if ($null -eq ($VhdObject).number) {
        return $false
    }
    else {
        return $true
    }

}
Function Mount-VhdxDisk {
    param (
        [string]$VHDXPath
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    
    $VhdxMount = Mount-VHD -Path $VHDXPath -Passthru
    $DiskNumber = ($VhdxMount | Get-Disk).Number
    $DiskNumber
}

Function Initialize-VhdxDisk {
    param (
        [UInt32]$DiskNumber
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    Show-OptionalUserExitAndContinue -Message "Continuing will overwrite the vhdx disk (all data will be lost)"

    if ((Get-Disk -Number $DiskNumber).PartitionStyle -eq "RAW") {
        Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
    }
    else {
        Clear-Disk -Number $DiskNumber -RemoveData -Confirm:$false
        Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
    }
}

Function Get-VmWindowsDriveMountParameters {
    # get and mount all drives of a vm
    # return the vhdx path with windows directory
    # dismount drive
    param (
        [Parameter(Mandatory = $true)]
        [string]$VmName
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    if (!(Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { Throw "VM must exist to get drive letter" }
    if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to get windows disk" }
    $VolumesWithWindowsDir = @()
    $HardDrives = (get-vm -name $VmName).HardDrives

    foreach ($HardDrive in $HardDrives) {
        $VhdxPath = $HardDrive.Path
        if (Test-IsVhdxMounted -VHDXPath $VhdxPath) { 
            Show-OptionalUserExitAndContinue -Message "VHDX is already mounted, continuing will dismount the disk"
            Dismount-VHD -Path $VhdxPath 
        }
        $VhdxMount = Mount-VHD -Path $VhdxPath -Passthru
        $DiskNumber = ($VhdxMount | Get-Disk).Number
        $MountedDrives = get-partition -DiskNumber $DiskNumber | where-Object { $_.DriveLetter -match '[a-z]' }
        
        
        foreach ($MountedDrive in $MountedDrives) {

            if (test-path -path (join-path -path ($MountedDrive.DriveLetter + ':') -childpath "Windows")) {
                $VolumesWithWindowsDir += @{ VhdxPath = $VhdxPath; VhdxPartitionNumber = $MountedDrive.PartitionNumber }
            }
        } 

        Dismount-VHD -Path $VhdxPath
    }

    if ($VolumesWithWindowsDir.Count -eq 0) {
        Throw "No drive with Windows directory found"
    }
    elseif ($VolumesWithWindowsDir.Count -eq 1) {
        return $VolumesWithWindowsDir[0]
    }
    else {
        Throw "Multiple drives with Windows directory found"

    }
}

Function Get-VhdxPartitionDriveLetter {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VhdxPath,
        [Parameter(Mandatory = $true)]
        [UInt32]$VhdxPartitionNumber
    )

    $MountedVmDrive = get-vhd -path $VhdxPath
    if (!($MountedVmDrive.Number)) {Throw "Vhd not mounted"}

    $DriveLetter = (get-disk -number $MountedVmDrive.Number | Get-Partition -number $VhdxPartitionNumber -ErrorAction SilentlyContinue).driveletter
    if (!($DriveLetter)) {Throw "Vhd partition not mounted"}

    $DriveLetter = $DriveLetter + ":"
    $DriveLetter
}