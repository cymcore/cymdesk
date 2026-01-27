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
$GitPortableUrl = "https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/PortableGit-2.48.1-64-bit.7z.exe"
$GitSavedFile = "C:\Windows\Setup\Scripts\PortableGit.exe"
$LogFile = "C:\cymlogs\SetupComplete.ps1.error"
$CymdeskLocation = "C:\cymdesk"
### Derived variables

### Custom

### Common

# Create common directories
if (!(Test-Path -Path 'C:\Temp')) { New-Item -Path 'C:\Temp' -ItemType Directory }

# Download git portable, extract and install it, clone cymdesk repository, change permissions
if (!(Test-Path -Path $CymdeskLocation)) { New-Item -Path $CymdeskLocation -ItemType Directory }
Invoke-WebRequest -Uri $GitPortableUrl -OutFile $GitSavedFile
cmd /c $GitSavedFile -o"C:\Windows\Setup\Scripts\Git" -y
cmd /c "cd $CymdeskLocation && C:\Windows\Setup\Scripts\Git\bin\git.exe -c http.sslBackend=openssl clone https://github.com/cymcore/cymdesk.git ."
icacls $CymdeskLocation /inheritance:d
icacls $CymdeskLocation /remove "Authenticated Users"

[System.Environment]::SetEnvironmentVariable('CYMDESKPATH', $CymdeskLocation, [System.EnvironmentVariableTarget]::Machine)
# Set in current session
$env:CYMDESKPATH = [System.Environment]::GetEnvironmentVariable("CYMDESKPATH", "Machine")

# Install winauto
powershell.exe -ExecutionPolicy bypass -File $CymdeskLocation\windows\apps\winauto\winauto.ps1 -action install

# Allow admin integrity level without uac prompt
# Note this should be re-enabled after sysadmin scripts run, but even if not winauto will re-enable it
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacSetting = "ConsentPromptBehaviorAdmin"
Set-ItemProperty -Path $regPath -Name $uacSetting -Value 0 -Force

# Delete autoattend file
Remove-Item -Path "C:\unattend.xml" -Force