### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Source scripts
. "./utils_pshelper.ps1"

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

Function Test-IsAdmin {

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
    }
    else {
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
    else {
        Show-OptionalUserExitAndContinue -Message "The destination path $DestinationPath already exists. Skipping git clone operation" -Color Yellow
        return
    }

    # TODO check destination path is empty or not
    Start-Process -FilePath "git" -ArgumentList "clone $GitRepoUrl $DestinationPath" -PassThru -NoNewWindow
    

}

Function Add-InitialGitConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$UserEmail
    )

    if (!(get-command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not found in the PATH"
    }
    
    if (!(Test-Path -Path c:\users\$UserName\.gitconfig)) {
        git config --global user.name $UserName
        git config --global user.email $UserEmail
        git config --global core.autocrlf false
        git config --global core.eol lf

    } 
    else {
        Show-OptionalUserExitAndContinue -Message "Git config already exists for $UserName, skipping operation" -Color Yellow
    }
}

Function Set-WslInstanceConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$InstanceCymdeskPath = "/mnt/c/xfer/cymdesk",
        [string]$UserName
    )
    
    $wslInstances = wsl.exe --list --quiet
    if (!($wslInstances -contains $Name)) { Throw "The wsl instance $Name does not exist" }

    # Interactive to set user and password 
    Show-UserKeyPressToContinue -Message "This will enter wsl instance for username and password config (or just enter if configure previously).  This is a interactive operation" -Color Yellow
    wsl.exe -d $Name

    # Check if the instance is configured previously
    try {
        wsl.exe -d $Name --user root stat /root/.cym_bashrc
         $isWslPreviouslyConfigured = $true
    }
    catch {
        $isWslPreviouslyConfigured = $false
    }
    if ($isWslPreviouslyConfigured) {
        Show-OptionalUserExitAndContinue -Message "The wsl instance $Name has already been configured previously, skipping operation" -Color Yellow
        return
    }

    try {
        wsl.exe -d $Name --user root ls $InstanceCymdeskPath
    }
    catch {
        Throw "The cymdesk path $InstanceCymdeskPath does not exist in the wsl instance $Name"
    }


    wsl.exe -d $Name --user root find $InstanceCymdeskPath -type f -name `"*.sh`"
    wsl.exe -d $Name --user root $InstanceCymdeskPath/wsl/host_user_profiles.sh --wslName=$Name --initWsl=true
    wsl.exe -d $Name --user $UserName $InstanceCymdeskPath/wsl/host_user_profiles.sh --wslName=$Name
    

}

Function Set-WindowsSystemAndAppDarkMode {
    # Set Windows to dark mode
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty -Path $RegPath -Name AppsUseLightTheme -Value 0
    Set-ItemProperty -Path $RegPath -Name SystemUsesLightTheme -Value 0
    RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters
    Write-Host "Dark mode has been enabled."

}
Function Set-WindowsFileExplorerHideFileExtensions {
    param (
        [bool]$HideFileExtensions
    )

    # Registry path for File Explorer settings
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    # Convert boolean to registry-friendly value (1 to hide, 0 to show)
    $HideValue = if ($HideFileExtensions) { 1 } else { 0 }

    Set-ItemProperty -Path $RegPath -Name HideFileExt -Value $HideValue

    if ($HideFileExtensions) {
        Write-Host "File extensions are now hidden in File Explorer. Log out required."
    }
    else {
        Write-Host "File extensions are now visible in File Explorer. Log out required."
    }
}


Function Set-WindowsFileExplorerShowHiddenItems {
    param (
        [bool]$ShowHiddenItems
    )

    # Registry path for File Explorer settings
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    # Convert boolean to registry-friendly value (1 for show, 2 for hide)
    $HiddenValue = if ($ShowHiddenItems) { 1 } else { 2 }

    Set-ItemProperty -Path $RegPath -Name Hidden -Value $HiddenValue

    if ($ShowHiddenItems) {
        Write-Host "Hidden files are now visible in File Explorer. Log out required."
    }
    else {
        Write-Host "Hidden files are now hidden in File Explorer. Log out required."
    }
}

Function Set-WindowsWallpaper {
    param (
        [Parameter(Mandatory = $true)]
        [string]$WallpaperPath
    )
    # Set the wallpaper using the registry
    $RegPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $RegPath -Name Wallpaper -Value $WallpaperPath
    RUNDLL32.EXE USER32.DLL, UpdatePerUserSystemParameters
    Write-Host "Wallpaper has been set to $WallpaperPath."
}

Function Install-WslDistribution {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DistroName, 
        [string]$Name
    )

    if (! $Name) {
        $Name = "main"
    }

    $wslInstances = wsl.exe --list --quiet
    if ($wslInstances -contains $Name) {
        Show-OptionalUserExitAndContinue -Message "The wsl instance $Name already exists, skipping wsl installation" -Color Yellow
        return
    }

    wsl.exe --install $DistroName --name $Name
}