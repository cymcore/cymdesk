### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
Function Get-GpuWindowsCompatibleOs {
    $build = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ($build.CurrentBuild -ge 19041 -and ($($build.editionid -like 'Professional*') -or $($build.editionid -like 'Enterprise*') -or $($build.editionid -like 'Education*'))) {
        Return $true
    }    
}

Function Get-GpuPartitionFriendlyName {
    param(
        [Parameter(Mandatory = $true)]
        $GpuDevice
    )

    $gpuParse = ($GpuDevice).Name.Split('#')[1]
    $driver = Get-WmiObject Win32_PNPSignedDriver | Where-Object {
        ($_.HardwareID -eq "PCI\$gpuParse") -or ($_.HardwareID -contains "PCI\$gpuParse")
    } | Select-Object -First 1 -ExpandProperty DeviceName

    if ([string]::IsNullOrWhiteSpace($driver)) {
        return ($GpuDevice).Name
    }

    return $driver
}

Function Get-GpuVmPartitionAdapterDevice {
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator" }

    $GpuDevices = (Get-WmiObject -Class "Msvm_PartitionableGpu" -ComputerName $env:COMPUTERNAME -Namespace "ROOT\virtualization\v2" -ErrorAction SilentlyContinue)

    if ($null -eq $GpuDevices) { Throw "No compatible GPU found." }

    $GpuDeviceList = @($GpuDevices)

    if ($GpuDeviceList.Count -eq 1) {
        return $GpuDeviceList[0]
    }

    Write-Host "Multiple partitionable GPUs found. Select one:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $GpuDeviceList.Count; $i++) {
        $friendlyName = Get-GpuPartitionFriendlyName -GpuDevice $GpuDeviceList[$i]
        Write-Host ("[{0}] {1}" -f ($i + 1), $friendlyName)
    }

    while ($true) {
        $selection = Read-Host "Enter selection (1-$($GpuDeviceList.Count))"
        $parsed = 0
        if ([int]::TryParse($selection, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $GpuDeviceList.Count) {
            return $GpuDeviceList[$parsed - 1]
        }
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    }
}
Function Get-GpuVmPartitionAdapterName {
    

    $GpuDevice = Get-GpuVmPartitionAdapterDevice
    $GpuDevice


}