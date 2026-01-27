# Sample command line: powershell.exe -ExecutionPolicy bypass -File C:\Users\ptimme01\.quick_access_links\vol1-onedrive\scm\cymdesk\windows\physical_machine_prep.ps1

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

Function Test-IsAdmin {

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}

# Ensure log directory of the log file exists
$LogDir = Split-Path $LogFile
if (!(Test-Path -Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory }

# Ensure script is running as admin 
if (-not (Test-IsAdmin)) {
    Throw "This script must be run as an administrator."
}

# Create common directories

if (!(Test-Path -Path 'C:\Temp')) { New-Item -Path 'C:\Temp' -ItemType Directory }

# Download git portable, extract and install it
if (!(Test-Path -Path $GitSavedFile)) { Invoke-WebRequest -Uri $GitPortableUrl -OutFile $GitSavedFile }
if (!(Test-Path -Path "C:\Windows\Setup\Scripts\Git")) { cmd /c $GitSavedFile -o"C:\Windows\Setup\Scripts\Git" -y }

# Clone cymdesk repository, change permissions, set environment variable
if (!(Test-Path -Path $CymdeskLocation)) { 
    New-Item -Path $CymdeskLocation -ItemType Directory 
    cmd /c "cd $CymdeskLocation && C:\Windows\Setup\Scripts\Git\bin\git.exe -c http.sslBackend=openssl clone https://github.com/cymcore/cymdesk.git ."
    icacls $CymdeskLocation /inheritance:d
    icacls $CymdeskLocation /remove "Authenticated Users"

    [System.Environment]::SetEnvironmentVariable('CYMDESKPATH', $CymdeskLocation, [System.EnvironmentVariableTarget]::Machine)
    # Set in current session
    $env:CYMDESKPATH = [System.Environment]::GetEnvironmentVariable("CYMDESKPATH", "Machine")
}

# Install winauto
powershell.exe -ExecutionPolicy bypass -File $CymdeskLocation\windows\apps\winauto\winauto.ps1 -action install
