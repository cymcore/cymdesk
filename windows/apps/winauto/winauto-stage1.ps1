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
if (!(get-command -name git.exe -ErrorAction SilentlyContinue)){Throw "Git is not installed"}
if (!((Get-Item Env:CYMDESKPATH -ErrorAction SilentlyContinue).Value)){Throw "Cymdesk path not set"}
if (!(test-path -path $env:CYMDESKPATH)){Throw "Cymdesk path does not exist"}

set-location -path $env:CYMDESKPATH

Start-ProcessWithTimeout -FilePath "git.exe" -ArgumentList "pull" -Timeout 300

}

Enable-AdminPromptUac
Get-CymdeskRepo