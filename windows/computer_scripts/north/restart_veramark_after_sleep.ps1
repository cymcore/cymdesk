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

### Defined variables
$LogFile = "C:\cymlogs\restart_verimark_after_sleep.ps1.error"
### Derived variables
if (!($env:CYMDESKPATH)) { Throw "CYMDESKPATH environment variable is not set. Cannot proceed." }
$CymdeskLocation = $env:CYMDESKPATH

# Confirm cymdesk is setup properly
if (!(Test-Path -Path $env:CYMDESKPATH)) { Throw "CYMDESKPATH path '$env:CYMDESKPATH' does not exist. Cannot proceed." }

# Source Dependent Scripts
if (Test-Path -Path "$CymdeskLocation\windows\scripts\admin_functions.ps1") {
    . "$CymdeskLocation\windows\scripts\admin_functions.ps1"
}
else {
    throw "cymdesk admin_functions.ps1 not found"
}
if (Test-Path -Path "$CymdeskLocation\windows\scripts\user_functions.ps1") {
    . "$CymdeskLocation\windows\scripts\user_functions.ps1"
}
else {
    throw "cymdesk user_functions.ps1 not found"
}

# Ensure script is not run as administrator
if (Test-IsAdmin) {throw "This script must not be run as administrator." }

# Ensure log directory of the log file exists
$LogDir = Split-Path $LogFile
if (!(Test-Path -Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory }

# Ensure log directory of the log file exists
$RunLogFile = "C:\cymlogs\restart_verimark_after_sleep.ps1.run"
$RunLogDir = Split-Path $RunLogFile
if (!(Test-Path -Path $RunLogDir)) { New-Item -Path $RunLogDir -ItemType Directory }

$StartMessage = "$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss") - Restart Veramark after sleep script started."
"$StartMessage" | Out-File -FilePath $RunLogFile -Append

# Give USB time to enumerate after wake from sleep - retry up to 20 times
Start-Sleep -Seconds 8
$device = $null
$maxRetries = 20
$retryCount = 0

while ($retryCount -lt $maxRetries -and -not $device) {
    $device = Get-PnpDevice |
    Where-Object {
        $_.FriendlyName -match 'Verimark|Fingerprint'
    }
    
    if (-not $device) { $retryCount++ }
    Start-Sleep -Seconds 2
}


if (-not $device) {
    throw "No Verimark fingerprint device found after $maxRetries attempts."
}

foreach ($d in $device) {
    Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
    Start-Sleep -Seconds 3
    Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
}

$EndMessage = "$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss") - Restart Veramark after sleep script ended."
"$EndMessage" | Out-File -FilePath $RunLogFile -Append