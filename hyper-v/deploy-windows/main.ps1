param (
    [Parameter(Mandatory = $true)]
    [string]$VmConfigDir
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

### Defined Variables
$ConfigsDir = ($PSScriptRoot + "\vm_configs") 

### Derived Variables

$FullVmConfigDir = ($ConfigsDir + "\" + $VmConfigDir)
Function Test-Admin {
    <#
                .SYNOPSIS
                    Short function to determine whether the logged-on user is an administrator.

                .EXAMPLE
                    Do you honestly need one?  There are no parameters!

                .OUTPUTS
                    $true if user is admin.
                    $false if user is not an admin.
            #>
    [CmdletBinding()]
    param()

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}



### Run Checks
if (!(Test-Admin)) { Throw "Please run as administrator"}
if (!(Test-Path -Path $ConfigsDir)) { Throw "VmConfigsDir ($ConfigsDir) not found"}
if (!(Test-Path -Path ($FullVmConfigDir))) { Throw "VmConfigDir ($VmConfigDir) not found"}
if (!(Test-Path -Path ($FullVmConfigDir + "\" + "config.ps1"))) { Throw "Config file (config.ps1) not found"}

### Source Files
. ($FullVmConfigDir + "\" + "config.ps1")
. $PSScriptRoot\create_vm.ps1
. $PSScriptRoot\image_windows_vhdx.ps1

### Main
$SysadminPassword = Read-Host -AsSecureString -Prompt "Enter sysadmin password"

New-HyperVVm @vm_config

New-OsImageDeploy -VmName $vm_config.VmName -VmPath $vm_config.VmPath -WindowsIso $windows_iso -OsConfig $os_config -FullVmConfigDir $FullVmConfigDir

if ($vm_config.AssignGpuParition) {
    . $PSScriptRoot\update_vm_gpu_files.ps1 -VmName $vm_config.VmName -VmPath $vm_config.VmPath 
}

Start-VM -Name $vm_config.VmName