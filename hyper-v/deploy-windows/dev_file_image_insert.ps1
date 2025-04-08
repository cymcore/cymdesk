param (
    [Parameter(Mandatory = $true)]
    [string]$VmName,
    [string]$Vhd = "d:\vm\$VmName\Virtual Hard Disks\$VmName.vhdx"
)

# Assumes f: is where the vhd got mounted

$UnattendFile = 'F:\unattend.xml'
$SysadminPassword = Read-Host -AsSecureString -Prompt "Enter sysadmin password"
Mount-VHD -Path $Vhd

Remove-Item -path f:\unattend.xml -Force
Remove-Item -path f:\windows\setup\scripts\SetupComplete.cmd -Force
Remove-Item -path f:\windows\setup\scripts\SetupComplete.ps1 -Force
Remove-Item -path f:\windows\setup\scripts\firstlogon.ps1 -Force


Copy-Item -Path './common_scripts/unattend.xml' -Destination 'F:\unattend.xml'
Copy-Item -Path './common_scripts/SetupComplete.cmd' -Destination 'F:\windows\setup\scripts\SetupComplete.cmd'
Copy-Item -Path './common_scripts/SetupComplete.ps1' -Destination 'F:\windows\setup\scripts\SetupComplete.ps1'
Copy-Item -Path './common_scripts/firstlogon.ps1' -Destination 'F:\windows\setup\scripts\firstlogon.ps1'

[xml]$xml = get-content -path $UnattendFile
($xml.unattend.settings.component | where-object {$_.autologon}).autologon.password.value = ([System.Net.NetworkCredential]::new("", $SysadminPassword).Password)
($xml.unattend.settings.component | where-object {$_.UserAccounts}).UserAccounts.LocalAccounts.localaccount.Password.Value = ([System.Net.NetworkCredential]::new("", $SysadminPassword).Password)
($xml.unattend.settings.component | where-object {$_.Computername}).Computername = $VmName
$xml.Save($UnattendFile)

Read-Host -Prompt "Modify any F:\ files, then press Enter to continue"
Dismount-VHD -Path $Vhd

$CheckpointName = "PreDeploymentCheckpoint"
Checkpoint-VM -Name $VmName -SnapshotName $CheckpointName