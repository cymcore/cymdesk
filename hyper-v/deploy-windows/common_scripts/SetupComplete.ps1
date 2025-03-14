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
New-Item -Path 'C:\Temp' -ItemType Directory

# Download git portable, extract and install it, clone cymdesk repository, change permissions
Invoke-WebRequest -Uri $GitPortableUrl -OutFile $GitSavedFile
cmd /c "C:\Windows\Setup\Scripts\PortableGit.exe" -o"C:\Windows\Setup\Scripts\Git" -y
cmd /c "cd C:\ && C:\Windows\Setup\Scripts\Git\bin\git.exe clone https://github.com/cymcore/cymdesk.git"
icacls c:\cymdesk /inheritance:d
icacls c:\cymdesk /remove "Authenticated Users"

[System.Environment]::SetEnvironmentVariable('CYMDESKPATH', $CymdeskLocation, [System.EnvironmentVariableTarget]::Machine)
$env:CYMDESKPATH = [System.Environment]::GetEnvironmentVariable("CYMDESKPATH", "Machine")

# Install winauto
powershell.exe -ExecutionPolicy bypass -File C:\cymdesk\windows\apps\winauto\winauto.ps1 -action install

# Allow admin integrity level without uac prompt
# Note this should be re-enabled after sysadmin scripts run, but even if not winauto will re-enable it
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacSetting = "ConsentPromptBehaviorAdmin"
Set-ItemProperty -Path $regPath -Name $uacSetting -Value 0 -Force

# Delete autoattend file
Remove-Item -Path "C:\unattend.xml" -Force