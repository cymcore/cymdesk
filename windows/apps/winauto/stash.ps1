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
        Install-Module -Scope AllUsers $ModuleName -Confirm:$False -Force
    }
}

Function Test-WingetInstalledApp {
    param(
        [string]$Id
    )
  
    if (Get-WinGetPackage | where-object { $_.id -eq $Id }) {
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
    $DefaultArgs = "--accept-source-agreements --accept-package-agreements"
    $CustomArgs = -join @($DefaultArgs, $CustomArgs)
 
    if (-not (Test-WingetInstalledApp -Id $Id)) {
        Install-WinGetPackage -Id $Id -Mode "Silent" -Custom $CustomArgs
    }
    
}
# Note: if winget arguments have both single and double quotes, use a here string
# $CustomArgs = @"
#  --override '/VERYSILENT /SP- /MERGETASKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
# "@

If (!(Get-PackageProvider | Where-Object { $_.Name -eq "NuGet" })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Install-PowershellModule -ModuleName "Microsoft.WinGet.Client"

winget source agree --source msstore


$GitCustomArgs = @"
--scope machine
"@
Install-WingetApp -Id Git.Git -CustomArgs $GitCustomArgs

$PowershellCustomArgs = @"
--source winget --scope machine
"@
Install-WingetApp -Id Microsoft.PowerShell -CustomArgs $PowershellCustomArgs

winget install --silent --id microsoft.powershell --scope machine --accept-source-agreements --accept-package-agreements