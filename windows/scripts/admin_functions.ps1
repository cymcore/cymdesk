### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Custom

Function New-LocalUserWithRandomPassword {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$UserDescription
    )

    $Password = Get-Random -Minimum 100000000000 -Maximum 999999999999
    $SecureStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    new-localuser -Description $UserDescription -PasswordNeverExpires -Password $SecureStringPassword -Name $UserName
    Disable-LocalUser -Name $UserName
    Add-LocalGroupMember -Group Users -Member $UserName
}

Function Set-StaticIpAddress {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IpAddress,
        [Parameter(Mandatory = $true)]
        [string]$IpSubnetMask,
        [Parameter(Mandatory = $true)]
        [string]$IpGateway
    )

    # -Dhcp Disabled parameter in Set-NetIPInterface does not work on a disconnected interface
    $SingleNetInterfaceIndex = (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "Ipv4" -and $_.ifIndex -ne 1 }).ifIndex
    Set-NetIPInterface -InterfaceIndex $SingleNetInterfaceIndex -Dhcp Disabled
    Remove-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    Remove-NetRoute -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    New-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -IPAddress $IpAddress -PrefixLength $IpSubnetMask -DefaultGateway $IpGateway
}

Function Set-DnsServerAddresses {
    param (
        [Parameter(Mandatory = $true)]
        [array]$DNSServers
    
    )
    Set-DnsClientServerAddress -InterfaceIndex  $SingleNetInterfaceIndex -ServerAddresses $DNSServers 
}

Function Set-VirtualizationFeaturesAll {
    Enable-WindowsOptionalFeature -FeatureName "VirtualMachinePlatform" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "HypervisorPlatform" -All -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName "Microsoft-Hyper-V" -All -Online -NoRestart
}

Function Set-AutoLogonCountFix {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $regValue = "AutoLogonCount"
    $newValue = 0
    Set-ItemProperty -Path $regPath -Name $regValue -Value $newValue -Type DWORD -Force
}

Function New-LocalSmbShare {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirPath,
        [Parameter(Mandatory = $true)]
        [string]$ShareName
    )
    if (!(Test-Path -Path $DirPath)) { New-Item -Path $DirPath -ItemType Directory }
    New-SmbShare -Path $DirPath -Name $ShareName -FullAccess Everyone
    Enable-NetFirewallRule -Name "FPS-SMB-In-TCP"
}

Function Set-RdpOn {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

Function Install-Wsl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    wsl.exe --install -d $DistroName
}

Function Add-LocalUserRdpGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName

    )

    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $UserName
}

function Set-LocalUserEnableAndPassword {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )
    Enable-LocalUser -Name $UserName
    $securePassword = Read-Host -AsSecureString -Prompt "Enter $UserName password"
    Set-LocalUser -Name $UserName -Password $securePassword 
}

Function Set-UacAdminPrompt {
    param (
        [Parameter(Mandatory=$true, ParameterSetName="SetA")]
        [switch]$PromptUac,
        [Parameter(Mandatory=$true, ParameterSetName="SetB")]
        [switch]$NoPromptUac
    )
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        $uacSetting = "ConsentPromptBehaviorAdmin"
    if ($PromptUac) {

        Set-ItemProperty -Path $regPath -Name $uacSetting -Value 5 -Force
    }
    elseif ($NoPromptUac) {
        Set-ItemProperty -Path $regPath -Name $uacSetting -Value 0 -Force
    }
}

Function New-EventLogSource {
    param (
        [Parameter(Mandatory = $true)]
        [string]$logName,
        [Parameter(Mandatory = $true)]
        [string]$source
    )
    if (!(Test-Admin)) {
        Throw "This script must be run as an administrator."
    }
    
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        New-EventLog -LogName $logName -Source $source
    }
}

Function New-EventLogEntry {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        [Parameter(Mandatory = $true)]
        [string]$LogSource,
        [Parameter(Mandatory = $true)]
        [int]$LogEventID,
        [Parameter(Mandatory = $true)]
        [string]$LogEntryType,
        [Parameter(Mandatory = $true)]
        [string]$LogMessage
    )

    # Check if the entry type is valid
    if (-not (Test-ValidLogEntryType -EntryType $LogEntryType)) {
        throw "Invalid entry type: $LogEntryType"
    }
    # Write the event to the log
    Write-EventLog -LogName $LogName -Source $LogSource -EventID $LogEventID -EntryType $LogEntryType -Message $LogMessage
}

Function Test-ValidLogEntryType {
    param (
        [Parameter(Mandatory = $true)]
        [string]$EntryType
    )

    # Define valid event log entry types
    $validTypes = @("Information", "Warning", "Error", "SuccessAudit", "FailureAudit")

    # Check if the input matches one of the valid types
    return $validTypes -contains $EntryType
}

Function New-EventLogTrigger {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName, 
        [Parameter(Mandatory = $true)]
        [string]$LogSource,
        [Parameter(Mandatory = $true)]
        [int]$EventID
    )

    # create TaskEventTrigger, use your own value in Subscription
    $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
    $Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
    $Trigger.Enabled = $True 
    $Trigger.Subscription = @"
<QueryList>
    <Query Id="0" Path="$LogName">
        <Select Path="$LogName">*[System[Provider[@Name="$LogSource"] and EventID=$EventID]]
        </Select>
    </Query>
</QueryList>
"@
    return $Trigger

}

Function Set-EnviromentVariableMachine {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
}