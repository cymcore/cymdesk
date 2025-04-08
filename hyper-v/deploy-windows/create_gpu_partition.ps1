### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
. $PSScriptRoot\utils_gpu-p.ps1

Function Set-VmConfigForGpuPartition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    if (!(Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { Throw "VM must exist to add GPU partition" }
    if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to add GPU partition" }

    ### Defined Variables
    $VmConfigForGpuPartition = @{
        VmName                      = $VmName
        LowMemoryMappedIoSpace      = 3GB
        HighMemoryMappedIoSpace     = 32GB
        GuestControlledCacheTypes   = $true
        AutomaticStopAction         = "ShutDown"
        AutomaticCheckpointsEnabled = $false
        CheckpointType              = "Standard"
    }

    ### Set VM properties for a gpu partition
    Set-Vm @VmConfigForGpuPartition
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false

}

Function Set-GpuPartitionConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    if (!(Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { Throw "VM must exist to add GPU partition" }
    if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to add GPU partition" }

    $GpuDevice = Get-GpuVmPartitionAdapterDevice

    Set-VMGpuPartitionAdapter -VMName $VmName `
        -MinPartitionVRAM $GpuDevice.MinPartitionVRAM `
        -MaxPartitionVRAM $GpuDevice.MaxPartitionVRAM `
        -OptimalPartitionVRAM $GpuDevice.OptimalPartitionVRAM `
        -MinPartitionEncode $GpuDevice.MinPartitionEncode `
        -MaxPartitionEncode $GpuDevice.MaxPartitionEncode `
        -OptimalPartitionEncode $GpuDevice.OptimalPartitionEncode `
        -MinPartitionDecode $GpuDevice.MinPartitionDecode `
        -MaxPartitionDecode $GpuDevice.MaxPartitionDecode `
        -OptimalPartitionDecode $GpuDevice.OptimalPartitionDecode `
        -MinPartitionCompute $GpuDevice.MinPartitionCompute `
        -MaxPartitionCompute $GpuDevice.MaxPartitionCompute `
        -OptimalPartitionCompute $GpuDevice.OptimalPartitionCompute
}
Function Add-GpuVmPartitionAdapter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
    if (!(Test-IsDesktopPC)) { Throw "This script is only for desktop systems" }
    if (!(Get-GpuWindowsCompatibleOs)) { Throw "This script is only for Windows 10 20H1 or Windows 11 (Pro or Enterprise)" }
    if (!(Test-IsHyperVEnabled)) { Throw "You need to enable hyper-v" }
    if (!(Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { Throw "VM must exist to add GPU partition" }
    if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to add GPU partition" }
    
    Set-VmConfigForGpuPartition -VmName $VmName

    $GpuName = Get-GpuVmPartitionAdapterName
    
    if ($GpuName -eq "AUTO") {
        Add-VMGpuPartitionAdapter -VMName $VmName
    }
    else {
        Add-VMGpuPartitionAdapter -VMName $VmName -InstancePath $((Get-GpuVmPartitionAdapterDevice).Name)
    }
    
    Set-GpuPartitionConfiguration -VmName $VmName
}



