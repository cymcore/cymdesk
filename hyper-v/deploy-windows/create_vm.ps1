
function New-HyperVVm {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$VmPath,
        [Parameter(Mandatory = $true)]
        [Int64]$VmMemory,
        [Parameter(Mandatory = $true)]
        [string]$VmSwitch,
        [Parameter(Mandatory = $true)]
        [UInt64]$VmVhdSize,
        [Parameter(Mandatory = $true)]
        [int]$VmProcessorCount,
        [Parameter(Mandatory = $true)]
        [bool]$AssignGpuParition,
        [Parameter(Mandatory = $true)]
        [bool]$CpuVirtualizationExtensions,
        [Parameter(Mandatory = $true)]
        [bool]$TpmEnabled,
        [Parameter(Mandatory = $true)]
        [bool]$SecureBootEnabled
    )

    if (get-vm -name $VmName -ErrorAction SilentlyContinue) {
        Throw "VM $VmName already exists"
    }

    $VmVhdPath = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")
    New-VM -Name $VmName -Generation 2 -BootDevice VHD -Path $VmPath -MemoryStartupBytes $VmMemory -SwitchName $VmSwitch -NewVHDSizeBytes $VmVhdSize -NewVHDPath $VmVhdPath
    Set-VMProcessor -VMName $VmName -Count $VmProcessorCount
    Add-VMDvdDrive -VMName $VmName
    Set-VM -Name $VmName -AutomaticCheckpointsEnabled $false
    Set-VM -Name $VmName -CheckpointType Standard
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false 
    Set-VMVideo -VMName $VmName -HorizontalResolution 1920 -VerticalResolution 1080


    if ($CpuVirtualizationExtensions) {
        Set-VMProcessor -VMName $VmName -ExposeVirtualizationExtensions $true
    }

    if ($TpmEnabled) {
        Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $VmName 
    }

    if ($SecureBootEnabled) {
        Set-VMFirmware -VMName $VmName -EnableSecureBoot On
    }

    if ($AssignGpuParition) {
        . $PSScriptRoot\create_gpu_partition.ps1
        Add-GpuVmPartitionAdapter -VmName $VmName
    }
}




