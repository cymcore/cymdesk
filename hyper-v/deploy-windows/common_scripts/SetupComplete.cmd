REM This scripts runs as elevated system context from autoattend.xml
REM SetupComplete.ps1 is for powershell that applies every install and also run in the system context
if not exist C:\cymlogs mkdir C:\cymlogs
powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\SetupComplete.ps1


