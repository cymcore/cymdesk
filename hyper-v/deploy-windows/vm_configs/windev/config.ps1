
# WindowsImageName must match the exactly so index can be found.  E.g. Get-WindowsImage -ImagePath h:\sources\install.wim
$windows_iso = @{
    WindowsIsoPath = "D:\sec_source\Win11_24H2_English_x64.iso"
    WindowsImageName = "Windows 11 Pro"
}
$vm_config = @{
    VmName    = "windev"
    VmPath    = "D:\vm\"
    VmProcessorCount = 4
    VmMemory  = 16GB
    VmSwitch  = "Client"
    VmVhdSize = 256GB
    AssignGpuParition = $false
    CpuVirtualizationExtensions = $true
    TpmEnabled = $true
    SecureBootEnabled = $true
}
$os_config  = @{

    
}

