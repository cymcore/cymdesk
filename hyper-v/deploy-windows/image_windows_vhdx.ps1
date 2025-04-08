### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
. $PSScriptRoot\utils_hyperv.ps1



Function New-UefiPartitionDisk {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$VmPath
    )
    ### Defined Variables

    ### Derived Variables

    $VHDXPath = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")

    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator"}
    if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to initialize it's disk" }

    if (Test-IsVhdxMounted -VHDXPath $VHDXPath) { 
        Show-OptionalUserExitAndContinue -Message "VHDX is already mounted, continuing will dismount the disk"
        Dismount-VHD -Path $VHDXPath 
    }

    $DiskNumber = Mount-VhdxDisk -VHDXPath $VHDXPath

    Initialize-VhdxDisk -DiskNumber $DiskNumber
    
    # Because powershell automatically creates this as a data disk with a reserve partion 1, but for operating system system must be partion 1
    Remove-Partition -DiskNumber $DiskNumber -PartitionNumber 1 -Confirm:$false 
    
    # Partitions have to be created in the following order:
    # 1. System Partition
    # 2. Microsoft Reserved Partition
    # 3. Windows Partition
    # 4. Recovery Partition
    $SystemPartition = New-Partition -DiskNumber $DiskNumber -Size 100MB -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -AssignDriveLetter
    Format-Volume -Partition $SystemPartition -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false | Out-Null
    $SystemDriveLetter = ($SystemPartition).DriveLetter

    New-Partition -DiskNumber $DiskNumber -Size 16MB -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}" | Out-Null

    $WindowsPartition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" -AssignDriveLetter
    Format-Volume -Partition $WindowsPartition -FileSystem NTFS -Confirm:$false | Out-Null
    $WindowsDriveLetter = ($WindowsPartition).DriveLetter
    $ReduceSize = $WindowsPartition.Size - 1GB
    $WindowsPartition | Resize-Partition -Size $ReduceSize

    $RecoveryPartition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
    Format-Volume -Partition $RecoveryPartition -FileSystem NTFS -NewFileSystemLabel "Recovery" -Confirm:$false | Out-Null

    $VmDriveLetters = @{
        SystemDriveLetter  = $SystemDriveLetter
        WindowsDriveLetter = $WindowsDriveLetter
    }
    $VmDriveLetters

}

Function Deploy-OsImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsIsoDriveLetter,
        [Parameter(Mandatory = $true)]
        [string]$WindowsImageName,
        [Parameter(Mandatory = $true)]
        [string]$WindowsDriveLetter,
        [Parameter(Mandatory = $true)]
        [string]$SystemDriveLetter
    )

    $WindowsImagePath = ($WindowsIsoDriveLetter + ":\sources\install.wim")
    $WindowsImageIndex = (Get-WindowsImage -ImagePath $WindowsImagePath | Where-Object { $_.ImageName -eq $WindowsImageName }).ImageIndex
    Expand-WindowsImage -ImagePath $WindowsImagePath -Index $WindowsImageIndex -ApplyPath ($WindowsDriveLetter + ":\")
    bcdboot ($WindowsDriveLetter + ":\Windows") /s ($SystemDriveLetter + ":") /f UEFI

  
}

Function Deploy-OsConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsDriveLetter,
        [Parameter(Mandatory = $true)]
        [hashtable]$OsConfig,
        [Parameter(Mandatory = $true)]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$FullVmConfigDir
    )

    if (!($SysadminPassword)) { $SysadminPassword = Read-Host -AsSecureString -Prompt "Enter sysadmin password" }
        
    $UnattendFile = $WindowsDriveLetter + ":\unattend.xml"
    $ScriptsDir = $WindowsDriveLetter + ":\Windows\Setup\Scripts\"
  
        
    New-Item -ItemType Directory -Path $ScriptsDir -Force
 
    Copy-Item -Path ($PSScriptRoot + "\common_scripts\unattend.xml") -Destination $UnattendFile
    Copy-Item -Path ($PSScriptRoot + "\common_scripts\SetupComplete.cmd") -Destination $ScriptsDir
    Copy-Item -Path ($PSScriptRoot + "\common_scripts\SetupComplete.ps1") -Destination $ScriptsDir
    Copy-Item -Path ($PSScriptRoot + "\common_scripts\firstlogon.ps1") -Destination $ScriptsDir
      
    [xml]$xml = get-content -path $UnattendFile
        ($xml.unattend.settings.component | where-object { $_.autologon }).autologon.password.value = ([System.Net.NetworkCredential]::new("", $SysadminPassword).Password)
        ($xml.unattend.settings.component | where-object { $_.UserAccounts }).UserAccounts.LocalAccounts.localaccount.Password.Value = ([System.Net.NetworkCredential]::new("", $SysadminPassword).Password)
        ($xml.unattend.settings.component | where-object { $_.Computername }).Computername = $VmName
    $xml.Save($UnattendFile)
}
Function New-OsImageDeploy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$VmPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$WindowsIso,
        [Parameter(Mandatory = $true)]
        [hashtable]$OsConfig,
        [Parameter(Mandatory = $true)]
        [string]$FullVmConfigDir
        
    )
    ### Run Pre-Checks
    if (!(Test-IsAdmin)) { Throw "Please run as administrator"}
    if (!(Test-Path -Path $VmPath)) { Throw "VmPath ($VmPath) not found"}
    if (!(test-path $FullVmConfigDir)) { Throw "VmConfigDir ($FullVmConfigDir) not found"}

    $VmDriveLetters = New-UefiPartitionDisk -VmName $VmName -VmPath $VmPath
    $WindowsIsoDriveLetter = Mount-ISOReliable -SourcePath $WindowsIso.WindowsIsoPath
    Deploy-OsImage -WindowsIsoDriveLetter $WindowsIsoDriveLetter -WindowsImageName $WindowsIso.WindowsImageName -WindowsDriveLetter $VmDriveLetters.WindowsDriveLetter -SystemDriveLetter $VmDriveLetters.SystemDriveLetter
    Deploy-OsConfig -VmName $VmName -FullVmConfigDir $FullVmConfigDir -OsConfig $OsConfig -WindowsDriveLetter $VmDriveLetters.WindowsDriveLetter
    
    $VHDXPath = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")
    Dismount-VHD -Path $VHDXPath

    Dismount-DiskImage -ImagePath $WindowsIso.WindowsIsoPath
}

