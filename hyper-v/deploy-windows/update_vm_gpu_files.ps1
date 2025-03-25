Param (
[Parameter(Mandatory = $true)]
[string]$VMName,
[Parameter(Mandatory = $true)]
[string]$VmPath,
[string]$Hostname = $ENV:Computername
)

### Source Files
. $PSSCriptRoot\add_vm_gpu_files.ps1
. $PSSCriptRoot\create_gpu_partition.ps1 ; $GpuName = Get-GpuVmPartitionAdapterName

$VM = Get-VM -VMName $VMName
$VHDXPath = ($VmPath + $VmName + "\Virtual Hard Disks\" + $VmName + ".vhdx")

If ($VM.state -eq "Running") {
    [bool]$state_was_running = $true
    }

if ($VM.state -ne "Off"){
    "Attemping to shutdown VM..."
    Stop-VM -Name $VMName -Force
    } 

While ($VM.State -ne "Off") {
    Start-Sleep -s 3
    "Waiting for VM to shutdown - make sure there are no unsaved documents..."
    }

"Mounting Drive..."
$VmDrive = Mount-VHD -Path $VHDXPath -PassThru
$DriveLetter =  (get-disk -Number ($VmDrive | Get-Disk).Number| get-partition | get-volume | Where-Object { $_.size -gt 5GB}).driveletter

"Copying GPU Files - this could take a while..."
Add-VMGPUPartitionAdapterFiles -hostname $Hostname -DriveLetter $DriveLetter -GPUName $GPUName

"Dismounting Drive..."
Dismount-VHD -Path $VHDXPath

If ($state_was_running){
    "Previous State was running so starting VM..."
    Start-VM $VMName
    }

"Done..."