
### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
Function Get-GpuWindowsCompatibleOs {
    $build = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ($build.CurrentBuild -ge 19041 -and ($($build.editionid -like 'Professional*') -or $($build.editionid -like 'Enterprise*') -or $($build.editionid -like 'Education*'))) {
        Return $true
    }    
}

Function Get-GpuVmPartitionAdapterDevice {
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }

    $GpuDevices = (Get-WmiObject -Class "Msvm_PartitionableGpu" -ComputerName $env:COMPUTERNAME -Namespace "ROOT\virtualization\v2" -ErrorAction SilentlyContinue)
    
    if ($null -eq $GpuDevices) {Throw "No compatible GPU found." }
    elseif ($GpuDevices -is [array]) { Throw "More than one GPU found." }
    else {
        $GpuDevice = $GpuDevices
        $GpuDevice
    }
}
Function Get-GpuVmPartitionAdapterName {
    $GpuDevice = Get-GpuVmPartitionAdapterDevice

    if (Test-IsWindows10) {
        $GpuName = "AUTO"
    }
    else {
        $GpuParse = ($GpuDevice).Name.Split('#')[1]
        $GpuName = Get-WmiObject Win32_PNPSignedDriver | where-object { ($_.HardwareID -eq "PCI\$GpuParse") } | select-object DeviceName -ExpandProperty DeviceName
    }
    $GpuName
}