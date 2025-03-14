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
# Note: if winget arguments have both single and double quotes, use a here string
# $CustomArgs = @"
#  --override '/VERYSILENT /SP- /MERGETASKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
# "@

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