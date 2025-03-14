<#
.SYNOPSIS
    Stage1 is the eventlog-trigger and run script of WinAuto
    
.DESCRIPTION
    Stage1 shell is powershell.exe
    Stage1 generally used for unattend.xml installations (why is uses out-of-box powershell.exe)

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    None

.LINK
    None

.NOTES
    None
#>

# Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Defined variables

# Derived variables


Function Enable-AdminPromptUac {
# Do not allow admin integrity level without uac prompt (default)
# Note during unattend.xml installations this is set 0 to allow admin integrity level without uac prompt (e.g. ip config and software installs)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacSetting = "ConsentPromptBehaviorAdmin"
if ((get-itemproperty -path $regPath -name $uacSetting).$uacSetting -ne 5) {
    Set-ItemProperty -Path $regPath -Name $uacSetting -Value 5 -Force
}
}

Function Get-CymdeskRepo{
if (!(get-command -name git.exe -ErrorAction SilentlyContinue)){return}
if (!(get-variable -name $env:CYMDESKPATH -ErrorAction SilentlyContinue)){return}
if (!(test-path -path $env:CYMDESKPATH)){return}

set-locaton -path $env:CYMDESKPATH
git pull
}

Enable-AdminPromptUac
Get-CymdeskRepo