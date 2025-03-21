### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Custom

Function Test-PowershellInstalledModule {
    param (
        [string]$ModuleName
    )
  
    if (Get-InstalledModule | Where-Object { $_.Name -eq $ModuleName }) {
        return $true
    }
    else {
        return $false
    }
}

Function Install-PowershellModule {
    param (
        [string]$ModuleName
    )
    if (-not (Test-PowershellInstalledModule -ModuleName $ModuleName)) {
        Install-Module $ModuleName -Confirm:$False -Force
    }
}

Function Test-WingetInstalledApp {
    param(
        [string]$Id
    )
    $WingetFilePath = "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
    
    if (!(test-path -path $WingetFilePath)) { throw "Winget is not installed" }

    $process = Start-Process -FilePath $WingetFilePath -Wait -NoNewWindow -PassThru -ArgumentList "list --id $Id --accept-source-agreements"

    if ($process.ExitCode -eq 0) {
        return $true
    }
    else {
        return $false
    }
}

Function Install-WingetApp {
    param(
        [string]$Id,
        [string]$CustomArgs
    )
    $DefaultArgs = "--accept-source-agreements --accept-package-agreements --silent"
    $CustomArgs = $DefaultArgs, $CustomArgs -join " "
    $WingetFilePath = "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
 
    if (-not (Test-WingetInstalledApp -Id $Id)) {
        $process = Start-Process -FilePath $WingetFilePath -Wait -NoNewWindow -PassThru -ArgumentList "install --id $Id $CustomArgs"
        if ($process.ExitCode -ne 0) {
            throw "Winget failed to install $Id"
        }
    }
    
}
Function Get-AreTwoFilesSame {
    param (
        [Parameter(Mandatory = $true)]
        [string]$File1,
        [Parameter(Mandatory = $true)]
        [string]$File2
    )

    $hash1 = Get-FileHash -Path $File1
    $hash2 = Get-FileHash -Path $File2

    return $hash1.Hash -eq $hash2.Hash
}

Function Get-WebFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RawUrl, 
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Invoke-WebRequest -Uri $RawUrl -OutFile $OutputPath
        

}

Function Test-Admin {

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}

Function Start-ProcessWithTimeout {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [int]$Timeout
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -NoNewWindow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while (!$process.HasExited -and $sw.Elapsed.TotalSeconds -lt $Timeout) {
        Start-Sleep -Seconds 1
    }

    if (!$process.HasExited) {
        Stop-Process -Id $process.Id -Force
        Throw "Process - $FilePath timed out"
    }else {
        return $process
    }
}

Function Copy-GitRepo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GitRepoUrl,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (!(get-command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not found in the PATH"
    }

    if (!(Test-Path -Path $DestinationPath)) {
        new-item -ItemType Directory -Path $DestinationPath -Force
    }

    $process = Start-Process -FilePath "git" -ArgumentList "clone $GitRepoUrl $DesinationPath" -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        throw "Failed to clone the repository $GitRepoUrl to $DestinationPath"
    }
}