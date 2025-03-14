<#
.SYNOPSIS
    WinAuto is a framework to automate running commands that need to be run as SYSTEM on Windows.  

.DESCRIPTION
    Creates a Windows Scheduled Task that runs daily and can be triggered by an event log entry.
    Must be run as an administrator.
    The Scheduled Task is run as SYSTEM and has the highest privileges.
    Has ability to run computer specific scripts.
    Does not try to catch up if it misses a run time.
    Can be run from cli or imported/sourced into another script.

.PARAMETER Action
    Note: if imported/sourced into another script, the Action parameter is not required.
    Install - Installs the WinAuto service.
    Uninstall - Uninstalls the WinAuto service.
    Update - Updates the WinAuto service primary script.
    Trigger - Triggers the WinAuto service.
    Run - Runs the WinAuto service.

.PARAMETER InstallLocation
    Default: C:\cymauto
    The directory where the WinAuto service will be installed.

.PARAMETER CymdeskLocation
    Default: C:\cymdesk
    The directory where the cymdesk repository is located.
    Cymdesk is a dependency of WinAuto.

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    PS> winauto.ps1 -Action Install

.LINK
    None

.NOTES
    None
#>

param(
    [ValidateSet("Install", "Uninstall", "Update", "Trigger", "Run")]
    [string]$Action,
    [string]$InstallLocation = "C:\cymauto",
    [string]$CymdeskLocation = "C:\cymdesk"
)

# Error Handling
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

# Defined Variables
$LogName = "Application"
$LogSource = "winauto"
$GithubUrl = "https://raw.githubusercontent.com/cymcore/cymdesk/refs/heads/main/windows/apps/winauto/"
$ScheduledTaskName = "WinAuto-Run"
$DailyRunTime = "3am"
$WinautoStage1File = "$WinAutoDir\winauto-stage1.ps1"
$WinautoStage2File = "$WinAutoDir\winauto-stage2.ps1"
$WinAutoComputerFile = "$WinAutoDir\$env:COMPUTERNAME.ps1"
$LogFile = "c:\cymlogs\winauto.ps1.error"

# Derived Variables
$WinAutoDir = $InstallLocation

# Source Dependent Scripts
if ($env:CYMDESKPATH) {
    $CymdeskLocation = $env:CYMDESKPATH
}
else {
    # Set and refresh CYMDESKPATH environment variable
    [System.Environment]::SetEnvironmentVariable('CYMDESKPATH', $CymdeskLocation, [System.EnvironmentVariableTarget]::Machine)
    $env:CYMDESKPATH = [System.Environment]::GetEnvironmentVariable("CYMDESKPATH", "Machine")
}

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

Function Install-WinAuto {
    if ($env:AUTOWINPATH) {
        throw "WinAuto is already installed, uninstall first"
    }
 
    # Set and refresh AUTOWINPATH environment variable
    [System.Environment]::SetEnvironmentVariable('AUTOWINPATH', $WinAutoDir, [System.EnvironmentVariableTarget]::Machine)
    $env:AUTOWINPATH = [System.Environment]::GetEnvironmentVariable("AUTOWINPATH", "Machine")
    
    
    ## Create winauto base directory
    if (!(Test-Path -Path $WinAutoDir)) {
        New-Item -Path $WinAutoDir -ItemType Directory -Force
        icacls $WinAutoDir /inheritance:d
        icacls $WinAutoDir /remove "Authenticated Users"
    }

    ## Download winauto files from GitHub
    $WinAutoFiles = @("winauto.ps1", "winauto-stage1.ps1", "winauto-stage1.ps1")
    foreach ($WinAutoFile in $WinAutoFiles) {
        if (!(Test-Path -Path "$WinAutoDir\$WinAutoFile")) {
            $RawUrl = "$GithubUrl/$WinAutoFile"
            $OutputPath = "$WinAutoDir\$WinAutoFile"
            Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
        }
    }

    ## Create scheduled task

    New-EventLogSource -logName $LogName -source $LogSource

    if (!(Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue)) {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $WinAutoDir\winauto.ps1 -action run"
        $Triggers = @(
            (New-ScheduledTaskTrigger -Daily -At $DailyRunTime),
            (New-EventLogTrigger -LogName $LogName -LogSource $LogSource -EventID 150)
        )
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 6)
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $ScheduledTaskName -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal 
    }

    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 105 -LogEntryType (Get-LogIdMetadata(105)).LogEntryType -LogMessage (Get-LogIdMetadata(105)).LogMessage

}

Function Invoke-WinAutoRunTrigger {
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 150 -LogEntryType (Get-LogIdMetadata(150)).LogEntryType -LogMessage (Get-LogIdMetadata(150)).LogMessage

}

Function Invoke-WinAutoRun {

    ## Download stage-1 script (remove first to get any updates)
    
    if (test-path -Path $WinautoStage1File) { Remove-Item -Path $WinautoStage1File }
    if (!(Test-Path -Path $WinautoStage1File)) {
        $RawUrl = "$GithubUrl/winauto-stage1.ps1"
        $OutputPath = $WinautoStage1File
        Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
    }

    ## Download stage-2 script (remove first to get any updates)

    if (test-path -Path $WinautoStage2File) { Remove-Item -Path $WinautoStage2File }
    if (!(Test-Path -Path $WinautoStage2File)) {
        $RawUrl = "$GithubUrl/winauto-stage2.ps1"
        $OutputPath = $WinautoStage2File
        Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
    }

    ## Download computer specific script (remove first to get any updates)
    if (test-path -Path $WinAutoComputerFile) { Remove-Item -Path $WinAutoComputerFile }
    try {
        if (!(Test-Path -Path $WinAutoComputerFile)) {
            $RawUrl = "$GithubUrl/$env:COMPUTERNAME.ps1"
            $OutputPath = $WinAutoComputerFile
            Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
        }
    }
    catch {
        New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 120 -LogEntryType (Get-LogIdMetadata(120)).LogEntryType -LogMessage (Get-LogIdMetadata(120)).LogMessage
    }
  
    ## Run scripts
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $PwshAvailable = $true
    }
    else {
        $PwshAvailable = $false
    }

    ### Stage-1 script
    write-output ("$(get-date) - stage1 starting") >> $LogFile
    . $WinautoStage1File >> $LogFile
    ### Stage-2 script
    if ($PwshAvailable) {
        write-output ("$(get-date) - stage2 starting") >> $LogFile
        pwsh.exe -ExecutionPolicy Bypass -File $WinautoStage2File >> $LogFile
    } 

    ### Computer specific script
    if ((Test-Path -Path $WinAutoComputerFile) -and ($PwshAvailable)) {
        write-output ("$(get-date) - $env:COMPUTERNAME starting") >> $LogFile
        pwsh.exe -ExecutionPolicy Bypass -File $WinAutoComputerFile >> $LogFile
    }

    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 110 -LogEntryType (Get-LogIdMetadata(110)).LogEntryType -LogMessage (Get-LogIdMetadata(110)).LogMessage
    Update-WinAuto
}
Function Uninstall-WinAuto {
    ## Remove winauto environment variable
    if ($env:AUTOWINPATH) {
        [System.Environment]::SetEnvironmentVariable('AUTOWINPATH', $null, [System.EnvironmentVariableTarget]::Machine)
        $env:AUTOWINPATH = [System.Environment]::GetEnvironmentVariable("AUTOWINPATH", [System.EnvironmentVariableTarget]::Machine)
    }
    ## Delete winauto base directory
    if (Test-Path -Path $WinAutoDir) {
        Remove-Item -Path $WinAutoDir -Force -Recurse
    }

    ## Delete scheduled task
    if (Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false

    }
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 106 -LogEntryType (Get-LogIdMetadata(106)).LogEntryType -LogMessage (Get-LogIdMetadata(106)).LogMessage

}

Function Get-LogIdMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LogEventID
    )
    # TODO: validate LogEventID
    $LogIdTable = @{
        100 = @{ LogEntryType = "Information"; LogMessage = "General Informational message" }
        105 = @{ LogEntryType = "Information"; LogMessage = "Install complete" }
        106 = @{ LogEntryType = "Information"; LogMessage = "Uninstall complete" }
        107 = @{ LogEntryType = "Information"; LogMessage = "Update complete" }
        110 = @{ LogEntryType = "Information"; LogMessage = "Run complete" }
        120 = @{ LogEntryType = "Information"; LogMessage = "No computer specific script found" }
        150 = @{ LogEntryType = "Information"; LogMessage = "Run trigger activated" }
        200 = @{ LogEntryType = "Warning"; LogMessage = "General Warning message" }
        300 = @{ LogEntryType = "Error"; LogMessage = "General Error message" }
        305 = @{ LogEntryType = "Error"; LogMessage = "Tried to run not as admin" }

    }
    return $LogIdTable[$LogEventID]
}

Function Update-WinAuto {
    ## Update winauto.ps1 file if needed (this gets executed at the end of the run action)
    ### Download and compare winauto.ps1 files 
    if (test-path -Path "$WinAutoDir\winauto.ps1.new") { Remove-Item -Path "$WinAutoDir\winauto.ps1.new" }
    $RawUrl = "$GithubUrl/winauto.ps1"
    $OutputPath = "$WinAutoDir\winauto.ps1.new"
    Get-WebFile -RawUrl $RawUrl -OutputPath $OutputPath
    
    if (!(Get-AreTwoFilesSame -File1 "$WinAutoDir\winauto.ps1" -File2 "$WinAutoDir\winauto.ps1.new")) {
        $shouldUpdate = $true
    }

    if ($shouldUpdate) {
        $UpdateCommand = { start-sleep -seconds 10 ; remove-item -Path "$using:WinAutoDir\winauto.ps1" -force ; rename-item -Path "$using:WinAutoDir\winauto.ps1.new" -NewName "$using:WinAutoDir\winauto.ps1" }
        Start-Job -ScriptBlock $UpdateCommand 
        New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 107 -LogEntryType (Get-LogIdMetadata(107)).LogEntryType -LogMessage (Get-LogIdMetadata(107)).LogMessage
        exit 0
    }

}
Function Main {
    switch ($Action) {
        "Install" { Install-WinAuto }
        "Uninstall" { Uninstall-WinAuto }
        "Update" { Update-WinAuto }
        "Trigger" { Invoke-WinAutoRunTrigger }
        "Run" { Invoke-WinAutoRun }
        default { write-host "Parameter Required: Run Get-Help" }
    }
    
}


if (-not (Test-Admin) -and ($Action -ne "Trigger")) {
    New-EventLogEntry -LogName $LogName -LogSource $LogSource -LogEventID 305 -LogEntryType (Get-LogIdMetadata(305)).LogEntryType -LogMessage (Get-LogIdMetadata(305)).LogMessage

    Throw "This script must be run as an administrator."
}

if ($null -eq $MyInvocation.PSCommandPath) {
    Main
}

