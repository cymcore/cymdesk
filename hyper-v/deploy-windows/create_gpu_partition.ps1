Function Get-DesktopPC {
    $isDesktop = $true
    if (Get-WmiObject -Class win32_systemenclosure | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14 }) {
        Write-Warning "Computer is a laptop. Laptop dedicated GPU's that are partitioned and assigned to VM may not work" 
        Write-Warning "Thunderbolt 3 or 4 dock based GPU's may work"
        $isDesktop = $false 
    }
    if (Get-WmiObject -Class win32_battery)
    { $isDesktop = $false }
    $isDesktop
}

Function Get-WindowsCompatibleOs {
    $build = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ($build.CurrentBuild -ge 19041 -and ($($build.editionid -like 'Professional*') -or $($build.editionid -like 'Enterprise*') -or $($build.editionid -like 'Education*'))) {
        Return $true
    }
    Else {
        Write-Warning "Only Windows 10 20H1 or Windows 11 (Pro or Enterprise) is supported"
        Return $false
    }
}

Function Get-HyperVEnabled {
    if (Get-WindowsOptionalFeature -Online | Where-Object FeatureName -Like 'Microsoft-Hyper-V-All') {
        Return $true
    }
    Else {
        Write-Warning "You need to enable Virtualisation in your motherboard and then add the Hyper-V Windows Feature and reboot"
        Return $false
    }
}

Function Get-IsWindows10 {

    $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
    
    # Check if the OS contains "Windows 10" but NOT "Server" or "Windows 11"
    if ($osVersion -match "Windows 10" -and $osVersion -notmatch "Server") {
        return $true
    }
    else {
        return $false
    }
}
Function Get-GpuVmPartitionAdapterName {
    $isWindows10 = Get-IsWindows10
    
    if ($isWindows10) {
        $GpuName = "AUTO"
    }
    else {
        $Devices = (Get-WmiObject -Class "Msvm_PartitionableGpu" -ComputerName $env:COMPUTERNAME -Namespace "ROOT\virtualization\v2").name
        if ($Devices.Count -gt 1) {
            Throw "More than one GPU found."
            exit 1
        } 

        $GpuParse = $Devices.Split('#')[1] 
        $GpuName = Get-WmiObject Win32_PNPSignedDriver | where-object { ($_.HardwareID -eq "PCI\$GpuParse") } | select-object DeviceName -ExpandProperty DeviceName
      
    }
    $GpuName
}
Function Add-GpuVmPartitionAdapter {
    param(
        [string]$VmName
    )

    # Check HOST (not VM) compatibility
    If (!((Get-DesktopPC) -and (Get-WindowsCompatibleOS) -and (Get-HyperVEnabled))) {
        Throw "Your system is not compatible with GPU partitioning"
    }


    $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if (!($vm)) {Throw "VM must exist to add GPU partition"}
    if ((Get-VM -Name $VmName).state -eq "On") {Throw "VM must not running to add GPU partition"}
    
    $GpuName = Get-GpuVmPartitionAdapterName

    Set-VM -Name $VmName -LowMemoryMappedIoSpace 3GB -HighMemoryMappedIoSpace 32GB -GuestControlledCacheTypes $true -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false -CheckpointType Standard 
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $false
    
    if ($GpuName -eq "AUTO") {
        Add-VMGpuPartitionAdapter -VMName $VmName
    }
    else {
        $PartitionableGPUList = Get-WmiObject -Class "Msvm_PartitionableGpu" -ComputerName $env:COMPUTERNAME -Namespace "ROOT\virtualization\v2" 
        $DeviceID = ((Get-WmiObject Win32_PNPSignedDriver | where-object { ($_.Devicename -eq "$GpuName") }).hardwareid).split('\')[1]
        $DevicePathName = ($PartitionableGPUList | Where-Object name -like "*$deviceid*").Name
        Add-VMGpuPartitionAdapter -VMName $VmName -InstancePath $DevicePathName

    }
    
}



