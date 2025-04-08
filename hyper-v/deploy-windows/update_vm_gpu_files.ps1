<#
.SYNOPSIS
    Adds gpu driver files to virtual machine drive
    Should be run after host updates it's gpu drivers 

.DESCRIPTION


.PARAMETER VmName
    Mandatory
    The name of the virtual machine

.PARAMETER LogFile
    Optional
    If you want the error function to log to a file

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    PS> winauto.ps1 -Action Install

.LINK
    None

.NOTES
    Don't run from vs code, run from terminal
    Run as administrator
#>
param (
    [Parameter(Mandatory = $true)]
    [string]$VmName,
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
. $PSScriptRoot\utils_hyperv.ps1
. $PSScriptRoot\utils_gpu-p.ps1

### Run Pre-Checks
if (!(Test-IsAdmin)) { Throw "Please run as administrator" }
if (!(Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { Throw "VM must exist to get drive letter" }
if ((Get-VM -Name $VmName).state -eq "On") { Throw "VM must not running to get windows disk" }

### Mount Vm disk with windows directory and get the drive letter
$VmWindowsDriveMountParameters = Get-VmWindowsDriveMountParameters -VmName $VmName
Mount-VHD -Path $VmWindowsDriveMountParameters.VhdxPath
$VmWindowsDriverLetter = Get-VhdxPartitionDriveLetter -VhdxPath $VmWindowsDriveMountParameters.VhdxPath -VhdxPartitionNumber $VmWindowsDriveMountParameters.VhdxPartitionNumber

# Set Windows directory and ensure required folders are present
$fVmWindowsDirectory = Join-Path -Path $VmWindowsDriverLetter -ChildPath "Windows"
(New-Item -ItemType Directory -Path "$fVmWindowsDirectory/System32/HostDriverStore/FileRepository" -Force -ErrorAction SilentlyContinue | Out-Null)
(New-Item -ItemType Directory -Path "$fVmWindowsDirectory/SysWOW64" -Force -ErrorAction SilentlyContinue | Out-Null)

# Get the gpu device drivers will corrospond to
$GpuDevice = Get-GpuVmPartitionAdapterDevice

$InstanceExpr = [regex]::New('^\\\\\?\\(.+)#.*$')
$InstanceId = $InstanceExpr.Replace($GpuDevice.Name, '$1').Replace('#', '\')
$GPU = Get-PnpDevice -InstanceId $InstanceId

# Start driver collection
Write-Host 'The next few steps may take a few minutes.'

Write-Host 'Getting display class devices.'
$PnPEntities = Get-CimInstance -ClassName 'Win32_PnPEntity' | Where-Object { $_.Class -like 'Display' }

Write-Host 'Getting display device drivers.'
$PnPSignedDrivers = Get-CimInstance -ClassName 'Win32_PnPSignedDriver' -Filter "DeviceClass = 'DISPLAY'"

Write-Host 'Getting all PnPSignedDriverCIMDataFiles.'
Write-Host 'This will take a few moments.'
$SignedDriverFiles = Get-CimInstance -ClassName 'Win32_PNPSignedDriverCIMDataFile'
Write-Host ('Found {0} files across all system drivers.' -f $SignedDriverFiles.Count)

Write-Host ('Getting driver package for {0}' -f $GPU.FriendlyName)
$PnPEntity = $PnPEntities | Where-Object { $_.InstanceId -eq $GPU.InstanceId }[0]

$PnPSignedDriver = $PnPSignedDrivers | Where-Object { $_.DeviceId -eq $GPU.InstanceId }

$SystemDriver = Get-CimAssociatedInstance -InputObject $PnPEntity -Association Win32_SystemDriverPNPEntity

$DriverStoreFolder = Get-Item -Path (Split-Path -Path $SystemDriver.PathName -Parent)
while ((Get-Item (Split-Path $DriverStoreFolder)).Name -notlike 'FileRepository') {
    $DriverStoreFolder = Get-Item -Path (Split-Path -Path $DriverStoreFolder -Parent)
}


Write-Host ('Found package {0}, copying DriverStore folder {1}' -f $PnPSignedDriver.InfName, (Split-Path $DriverStoreFolder -Leaf))
$TempDriverStore = ('{0}/System32/HostDriverStore/FileRepository/{1}' -f $fVmWindowsDirectory, $DriverStoreFolder.Name)
$DriverStoreFolder | Copy-Item -Destination $TempDriverStore -Recurse -Force
Write-Host ('Copied {0} of {1} files to temporary directory' -f (Get-ChildItem -Path $TempDriverStore -Recurse).Count, (Get-ChildItem -Path $DriverStoreFolder -Recurse).Count)

Write-Host ('Getting files from System32 and SysWOW64')
$DriverFiles = ($SignedDriverFiles | Where-Object { $_.Antecedent.DeviceID -like $GPU.DeviceID }).Dependent.Name | Sort-Object
$NonDriverStoreFiles = $DriverFiles.Where{ $_ -notlike '*DriverStore*' }

Write-Host('Found {0} files, copying' -f $NonDriverStoreFiles.Count)
$NonDriverStoreFiles | ForEach-Object -Process {
    $TargetPath = Join-Path -Path $fVmWindowsDirectory -ChildPath $_.ToLower().Replace(('{0}\' -f $Env:SYSTEMROOT.ToLower()), '')
    # make sure the parent folder exists
                    (New-Item -ItemType directory -Path (Split-Path -Path $TargetPath -Parent) -Force -ErrorAction SilentlyContinue | Out-Null)
    Write-Host ('  - {0} -> {1}' -f $_, $TargetPath)
    Copy-Item -Path $_ -Destination $TargetPath -Force -Recurse
}
dismount-vhd -Path $VmWindowsDriveMountParameters.VhdxPath
Write-Host ('Driver package generation for {0} complete.' -f $GPU.FriendlyName)



