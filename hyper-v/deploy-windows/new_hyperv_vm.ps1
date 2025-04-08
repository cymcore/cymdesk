
function New-HyperVVm {
    <#
.SYNOPSIS
Create a new Hyper-V VM

.DESCRIPTION
Creates a generation 2 Hyper-V VM with the dynamic memory disabled, a DVD drive, checkpoints disabled, and resolution set to 1920x1080

.PARAMETER VmName
<String> The name of the VM in Hyper-V

.PARAMETER VmPath
<String> The path where the VM will be created

.PARAMETER VmMemory
<Int64> The amount of memory to assign to the VM
Can use the GB suffix

.PARAMETER VmSwitch
<String> Only one network interface is supported
This parameter is the name of the virtual switch for that interface

.PARAMETER VmVhdSize
<UInt64> The size of the VHD in bytes
Can use the GB suffix

.PARAMETER VmProcessorCount
<Int64> The number of processors to assign to the VM

.PARAMETER AssignGpuParition
<Boolean> Whether to assign a GPU partition to the VM (using GPU-P)

.PARAMETER CpuVirtualizationExtensions
<Boolean> Whether to expose virtualization extensions to the VM
Needed for nested virtualization

.PARAMETER TpmEnabled
<Boolean> Whether to enable the TPM for the VM

.PARAMETER SecureBootEnabled
<Boolean> Whether to enable secure boot for the VM

.EXAMPLE
An example

.NOTES
General notes
#>
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

    ### Run Pre-Checks
    if (get-vm -name $VmName -ErrorAction SilentlyContinue) {
        Throw "VM $VmName already exists"
    }

    # As of 3-28-25, gpu and virtualization don't work for cuda
    if ($AssignGpuParition -and $CpuVirtualizationExtensions) {Throw "As of 3-28-25, gpu and virtualization don't work for cuda"}

    ### Create VM
    $NewVmParams = @{
        Name               = $VmName
        Generation         = 2
        BootDevice         = "VHD"
        Path               = $VmPath
        MemoryStartupBytes = $VmMemory
        SwitchName         = $VmSwitch
        NewVHDSizeBytes    = $VmVhdSize
        NewVHDPath         = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")
    }

    New-VM @NewVmParams

    Set-VMProcessor -VMName $VmName -Count $VmProcessorCount
    Add-VMDvdDrive -VMName $VmName
    Set-VM -Name $VmName -AutomaticCheckpointsEnabled $false
    Set-VM -Name $VmName -CheckpointType Standard
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false 
    Set-VMVideo -VMName $VmName -HorizontalResolution 1920 -VerticalResolution 1080

    # Set optional features
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




