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
$LogFile = "C:\cymlogs\north.ps1.error"
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

# Ensure log directory of the log file exists
$LogDir = Split-Path $LogFile
if (!(Test-Path -Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory }

Function New-VermarkRestartScheduledTask {
    $LogName = "System"
    $LogSource = "Microsoft-Windows-Power-Troubleshooter"
    $ScheduledTaskName = "cym-restart-verimark-after-sleep"

    if (!(Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue)) {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $CymdeskLocation\windows\computer_scripts\north\restart_veramark_after_sleep.ps1"
        $Triggers = @(
            (New-EventLogTrigger -LogName $LogName -LogSource $LogSource -EventID 1)
        )
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 6)
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $ScheduledTaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal 
    }
}

# New-VermarkRestartScheduledTask


