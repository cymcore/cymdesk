param (
    [Parameter(Mandatory = $true)]
    [string]$VmConfigDir,
    [string]$ConfigsDir = ($PSScriptRoot + "\vm_configs"),
    [string]$LogFile
)

### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

trap {
    Show-ErrorAndStackTrace -ErrorRecord $_
}

# Function to log detailed error information, including stack trace
Function Show-ErrorAndStackTrace {
    param ([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $ErrorGuid = [guid]::NewGuid()
    $ErrorDetails = @()
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $ErrorDetails += "ERROR_START_$ErrorGuid"
    $ErrorDetails += "ERRORMSG: $($ErrorRecord.Exception.Message)"
    $ErrorDetails += "SOURCE: $($ErrorRecord.InvocationInfo.ScriptName)"
    $ErrorDetails += "LINENUMBER: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
    $ErrorDetails += "LINEDETAIL: $($ErrorRecord.InvocationInfo.Line)"
    $ErrorDetails += "STATEMENT: $($ErrorRecord.InvocationInfo.Statement)"
    $ErrorStackTrace = $ErrorRecord.ScriptStackTrace -split "`n"
    foreach ($ErrorLine in $ErrorStackTrace) {
        $ErrorDetails += "STACKTRACE: $ErrorLine"
    }
    $ErrorDetails += "ERROR_END_$ErrorGuid"
   
    foreach ($ErrorDetail in $ErrorDetails) {
        Write-Host("$TimeStamp - $ErrorDetail")
        if ($LogFile) {
            "$TimeStamp - $ErrorDetail" | Out-File -FilePath $LogFile -Append
        }
    }
}

### Source Files
. $PSScriptRoot\utils_pshelper.ps1
. $PSScriptRoot\utils_windows.ps1
. $PSScriptRoot\new_hyperv_vm.ps1
. $PSScriptRoot\image_windows_vhdx.ps1

### Defined Variables

### Derived Variables
$FullVmConfigDir = (join-path -path $ConfigsDir -childpath $VmConfigDir)

### Run Pre-Checks
if (!(Test-Path -Path $ConfigsDir)) { Throw "VmConfigsDir ($ConfigsDir) not found" }
if (!(Test-Path -Path ($FullVmConfigDir))) { Throw "VmConfigDir ($VmConfigDir) not found" }
if (!(Test-Path -Path ($FullVmConfigDir + "\" + "config.ps1"))) { Throw "Config file (config.ps1) not found" }
if (!(Test-IsAdmin)) { Throw "Please run as administrator" }

### Source Config File
. ($FullVmConfigDir + "\" + "config.ps1")

### Main
if (!($SysadminPassword)) {
$SysadminPassword = Read-Host -AsSecureString -Prompt "Enter sysadmin password"
}

New-HyperVVm @vm_config

$OsImageDeployConfig = @{
    VmName          = $vm_config.VmName
    VmPath          = $vm_config.VmPath
    WindowsIso      = $windows_iso
    OsConfig        = $os_config
    FullVmConfigDir = $FullVmConfigDir
} 

New-OsImageDeploy @OsImageDeployConfig

if ($vm_config.AssignGpuParition) {
    . $PSScriptRoot\update_vm_gpu_files.ps1 -VmName $vm_config.VmName
}

Start-VM -Name $vm_config.VmName