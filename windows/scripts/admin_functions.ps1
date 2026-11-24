### Error Handling
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

### Defined variables

### Derived variables

### Source scripts
. "$PSScriptRoot/utils_pshelper.ps1"

### Custom

Function New-LocalUserWithRandomPassword {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$UserDescription
    )

    $TestUserExists = get-localuser | where-object { $_.name -eq $UserName }
    if ($TestUserExists) {
        Show-OptionalUserExitAndContinue -Message "User $UserName already exists, skipping operation" -Color Yellow
        return
    }

    $Password = Get-Random -Minimum 100000000000 -Maximum 999999999999
    $SecureStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    new-localuser -Description $UserDescription -PasswordNeverExpires -Password $SecureStringPassword -Name $UserName -ErrorAction SilentlyContinue
    Disable-LocalUser -Name $UserName
    Add-LocalGroupMember -Group Users -Member $UserName -ErrorAction SilentlyContinue
}

Function Set-StaticIpAddress {
    [CmdletBinding(DefaultParameterSetName = "IpParameters")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "IpParameters")]
        [ValidateNotNullOrEmpty()]
        [string]$IpAddress,
        [Parameter(Mandatory = $true, ParameterSetName = "IpParameters")]
        [ValidateNotNullOrEmpty()]
        [string]$IpSubnetMask,
        [Parameter(Mandatory = $true, ParameterSetName = "IpParameters")]
        [ValidateNotNullOrEmpty()]
        [string]$IpGateway,
        [Parameter(Mandatory = $true, ParameterSetName = "JsonFile")]
        [ValidateNotNullOrEmpty()]
        [string]$JsonFile
    )

    if ($PSCmdlet.ParameterSetName -eq "JsonFile") {
        $JsonContent = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json

        if (
            [string]::IsNullOrWhiteSpace($JsonContent.IpAddress) -or
            [string]::IsNullOrWhiteSpace($JsonContent.IpSubnetMask) -or
            [string]::IsNullOrWhiteSpace($JsonContent.IpGateway)
        ) {
            throw "JsonFile must contain IpAddress, IpSubnetMask, and IpGateway properties."
        }

        $IpAddress = $JsonContent.IpAddress
        $IpSubnetMask = $JsonContent.IpSubnetMask
        $IpGateway = $JsonContent.IpGateway
    }

    # -Dhcp Disabled parameter in Set-NetIPInterface does not work on a disconnected interface
    $SingleNetInterfaceIndex = (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "Ipv4" -and $_.ifIndex -ne 1 -and $_.InterfaceAlias -notlike "vEthernet*" }).ifIndex
    if ($SingleNetInterfaceIndex.Count -gt 1) { Throw "More than one network interface, time to debug and add more criteria to the filter" }
    Set-NetIPInterface -InterfaceIndex $SingleNetInterfaceIndex -Dhcp Disabled
    Remove-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    Remove-NetRoute -InterfaceIndex $SingleNetInterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue | out-null
    New-NetIPAddress -InterfaceIndex $SingleNetInterfaceIndex -IPAddress $IpAddress -PrefixLength $IpSubnetMask -DefaultGateway $IpGateway
}

Function Set-DnsServerAddresses {
    [CmdletBinding(DefaultParameterSetName = "DnsServers")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "DnsServers")]
        [ValidateNotNullOrEmpty()]
        [string[]]$DNSServers,
        [Parameter(Mandatory = $true, ParameterSetName = "JsonFile")]
        [ValidateNotNullOrEmpty()]
        [string]$JsonFile
    )

    if ($PSCmdlet.ParameterSetName -eq "JsonFile") {
        $JsonContent = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json
        $DNSServers = @($JsonContent.DnsServers)

        if ($DNSServers.Count -eq 0) {
            throw "JsonFile must contain a DnsServers element with at least one DNS server."
        }
    }

    $SingleNetInterfaceIndex = (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "Ipv4" -and $_.ifIndex -ne 1 }).ifIndex
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
    New-SmbShare -Path $DirPath -Name $ShareName -FullAccess Everyone -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -Name "FPS-SMB-In-TCP" -ErrorAction SilentlyContinue
}

Function Set-RdpOn {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
}

Function Install-Wsl {

    wsl --install --no-distribution
}

Function Install-MsiPackage {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MsiPath,
        [string]$AdditionalArguments,
        [string]$WingetDetectionString
    )

    # Complex example: Install-MsiPackage -MsiPath "C:\temp\myapp.msi" -AdditionalArguments '/L*v "C:\temp\my install.log" TRANSFORMS="C:\temp\my transform.mst"'

    if ($WingetDetectionString) {
        if (!(Get-Command -Name "winget" -ErrorAction SilentlyContinue)) {
            throw "winget is not available, but WingetDetectionString was specified: $WingetDetectionString"
        }

        $WingetOutput = @(winget list)
        if ($LASTEXITCODE -ne 0) {
            throw "winget list failed with exit code $LASTEXITCODE"
        }

        $IsWingetListed = $WingetOutput | Select-String -Pattern $WingetDetectionString -SimpleMatch -Quiet
        if ($IsWingetListed) {
            Write-Host "$WingetDetectionString is already installed according to winget. Skipping MSI installation."
            return
        }
    }

    if (!(Test-Path -Path $MsiPath)) {
        throw "MSI file not found: $MsiPath"
    }

    if ([System.IO.Path]::GetExtension($MsiPath) -ne ".msi") {
        throw "File must be an .msi package: $MsiPath"
    }

    $ResolvedMsiPath = (Resolve-Path -Path $MsiPath).Path
    $ArgumentList = "/i `"$ResolvedMsiPath`" /qn /norestart"
    if ($AdditionalArguments) {
        $ArgumentList = "$ArgumentList $AdditionalArguments"
    }

    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait -NoNewWindow -PassThru
    if ($Process.ExitCode -notin @(0, 1641, 3010)) {
        throw "MSI install failed for $ResolvedMsiPath with exit code $($Process.ExitCode)"
    }
}


Function Add-LocalUserRdpGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName

    )

    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $UserName -ErrorAction SilentlyContinue
}

function Set-LocalUserEnableAndPassword {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName
    )

    $TestUserExists = get-localuser | where-object { $_.name -eq $UserName }
    if ($TestUserExists) {
        write-host "User $UserName already exists, press 'y' to continue changing password or 'n' (or wait) to skip operation" -ForegroundColor Yellow
        $timeout = 10
        while ((++$counter) -lt $timeout) {
            # Countdown logic and display)
            if ($($counter) -eq 1) { write-host("$timeout ") -NoNewline } # Downside of initialization of counter in the while loop declaration
            Start-Sleep -Seconds 1
            write-host "$($timeout - $counter)  " -NoNewline
            if ($($timeout - $counter) -eq 1) { write-host("`r") }
        
            if ([Console]::KeyAvailable) {
                # A key was pressed, check if it's the Enter and Spacebar key
                $Key = [Console]::ReadKey($true).Key
        
                if ($Key -eq [ConsoleKey]::y) {
                    write-host("`r")
                    Write-Host "The "y" key pressed, continue to user password prompt..."
                    $shouldContinue = $true
                    break
                }
                if ($Key -eq [ConsoleKey]::n) {
                    write-host("`r")
                    Write-Host "The "n" key pressed, skipping operation..."
                    $shouldContinue = $false
                    break
                }
            }
   
        }
        if (($shouldContinue -eq $false) -or ($null -eq $shouldContinue)) { return }
    }

    Enable-LocalUser -Name $UserName
    $securePassword = Read-Host -AsSecureString -Prompt "Enter $UserName password"
    Set-LocalUser -Name $UserName -Password $securePassword 
}

Function Set-UacAdminPrompt {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "SetA")]
        [switch]$PromptUac,
        [Parameter(Mandatory = $true, ParameterSetName = "SetB")]
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
    if (!(Test-IsAdmin)) {
        Throw "This function must be run as an administrator."
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

Function Test-IsAdmin {

    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
 
    return $isAdmin
}

Function Install-PowershellWingetClient {

    powershell.exe -ExecutionPolicy bypass -command { Install-PackageProvider -Name NuGet -Force | Out-Null }
    powershell.exe -ExecutionPolicy bypass -command { Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null }

} 


Function Update-Winget {

    $WingetFilePath = "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
    
    # Check if winget is installed
    if (!(Test-Path -Path $WingetFilePath)) { throw "Winget is not installed." }

    # Check powershell winget powershell module is installed
    $WingetModule = Get-Module -Name Microsoft.WinGet.Client -ListAvailable
    if (!($WingetModule)) { throw "Powershell Microsoft.WinGet.Client module is not installed." }

    Repair-WinGetPackageManager -Force -Latest
}

Function Set-InitialWingetEnvironment {
    $WingetFilePath = "C:\Users\$($env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
    
    # After windows sysadmin loads wait for winget to be installed
    $counter = 0
    while (!(test-path -path $WingetFilePath) -and ($counter -lt 30)) {
        write-host "Waiting for winget, $(300 - $counter*10) seconds left before giving up"
        Start-Sleep -Seconds 10
        $counter++ 
    }

    if (!(Test-Path -Path $WingetFilePath)) { throw "Winget is not installed." }

    Install-PowershellWingetClient
    Update-Winget

}

Function Set-RdpFirewallRuleAllowIp {
    <#
    .SYNOPSIS
        Configures the allowed remote addresses for Remote Desktop firewall rules.

    .DESCRIPTION
        Adds supplied IP addresses to every firewall rule in the Remote Desktop
        display group. Use ResetAllowedRemoteAddresses to replace the existing
        addresses instead.

        Before making changes, this function verifies that every rule in the
        display group has the same allowed remote addresses. An exception is
        thrown when the rules have different addresses, preventing the function
        from obscuring an inconsistent configuration.

        Addresses can be supplied directly or read from the
        RdpAllowIpAddresses property of a JSON file.

    .PARAMETER IpAddresses
        One or more IPv4 or IPv6 addresses to allow. This parameter is mutually
        exclusive with JsonFile.

    .PARAMETER JsonFile
        Path to a JSON file containing an RdpAllowIpAddresses property with at
        least one IPv4 or IPv6 address. This parameter is mutually exclusive
        with IpAddresses.

    .PARAMETER ResetAllowedRemoteAddresses
        Replaces the existing allowed addresses with the supplied addresses.
        When omitted, the supplied addresses are added to the existing
        addresses.

    .EXAMPLE
        Set-RdpFirewallRuleAllowIp -IpAddresses "192.0.2.10", "2001:db8::10"

        Adds the two addresses while preserving the current allowed addresses.

    .EXAMPLE
        Set-RdpFirewallRuleAllowIp `
            -JsonFile "C:\Config\rdp.json" `
            -ResetAllowedRemoteAddresses

        Replaces the allowed addresses with those in the JSON file's
        RdpAllowIpAddresses property.
    #>
    [CmdletBinding(DefaultParameterSetName = "IpAddresses")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "IpAddresses")]
        [ValidateNotNullOrEmpty()]
        [string[]]$IpAddresses,
        [Parameter(Mandatory = $true, ParameterSetName = "JsonFile")]
        [ValidateNotNullOrEmpty()]
        [string]$JsonFile,
        [switch]$ResetAllowedRemoteAddresses
    )

    # Find every firewall rule in the Remote Desktop display group.
    $RdpFirewallRules = @(Get-NetFirewallRule -DisplayGroup "Remote Desktop")
    if ($RdpFirewallRules.Count -eq 0) {
        throw "No firewall rules were found in the Remote Desktop display group."
    }

    # Read and compare each rule's addresses before changing any rule.
    $CurrentRemoteAddresses = $null
    $CurrentRemoteAddressesKey = $null
    foreach ($RdpFirewallRule in $RdpFirewallRules) {
        $RuleRemoteAddresses = @(
            Get-NetFirewallAddressFilter `
                -AssociatedNetFirewallRule $RdpFirewallRule |
            Select-Object -ExpandProperty RemoteAddress |
            Sort-Object -Unique
        )
        $RuleRemoteAddressesKey = $RuleRemoteAddresses -join "`n"

        if ($null -eq $CurrentRemoteAddresses) {
            $CurrentRemoteAddresses = $RuleRemoteAddresses
            $CurrentRemoteAddressesKey = $RuleRemoteAddressesKey
        }
        elseif ($RuleRemoteAddressesKey -ne $CurrentRemoteAddressesKey) {
            throw "Group Remote Desktop firewall rules do not all have the same allowed remote addresses."
        }
    }

    # When a JSON file is supplied, load addresses from its configured property.
    if ($PSCmdlet.ParameterSetName -eq "JsonFile") {
        $JsonContent = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json
        $IpAddresses = @($JsonContent.RdpAllowIpAddresses)

        if ($IpAddresses.Count -eq 0) {
            throw "JsonFile must contain a RdpAllowIpAddresses property with at least one IP address."
        }
    }

    # Validate and normalize all supplied IPv4 and IPv6 addresses.
    $NormalizedIpAddresses = foreach ($IpAddress in $IpAddresses) {
        if ([string]::IsNullOrWhiteSpace($IpAddress)) {
            throw "RdpAllowIpAddresses cannot contain an empty IP address."
        }

        $ParsedAddress = $null
        if (-not [System.Net.IPAddress]::TryParse($IpAddress, [ref]$ParsedAddress)) {
            throw "Invalid IP address: '$IpAddress'"
        }

        $ParsedAddress.ToString()
    }

    # Remove duplicate supplied addresses.
    $NormalizedIpAddresses = $NormalizedIpAddresses | Select-Object -Unique

    # Preserve the common current addresses unless a reset was explicitly requested.
    if (-not $ResetAllowedRemoteAddresses) {
        $NormalizedIpAddresses = @(
            $CurrentRemoteAddresses
            $NormalizedIpAddresses
        ) | Select-Object -Unique
    }

    # Apply the same final address set to every Remote Desktop firewall rule.
    Set-NetFirewallRule `
        -DisplayGroup "Remote Desktop" `
        -RemoteAddress $NormalizedIpAddresses `
        -Enabled True
}


function Get-UserHomeDirectory {
    <#
    .SYNOPSIS
        Resolves a local Windows account name to its profile directory.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Username
    )

    # Translate the account name to the SID stored by Win32_UserProfile.
    $Account = [Security.Principal.NTAccount]::new($Username)
    $AccountSid = $Account.Translate(
        [Security.Principal.SecurityIdentifier]
    ).Value

    # Select the profile by exact SID to avoid prefix-based username collisions.
    $Profile = Get-CimInstance Win32_UserProfile |
    Where-Object {
        $_.SID -eq $AccountSid -and $_.LocalPath
    }

    # Return the path for Get-SshPaths to build the user's .ssh location.
    return $Profile.LocalPath
}

function Get-SshPaths {
    <#
    .SYNOPSIS
        Returns paths used by Windows OpenSSH and the applicable authorized_keys file.

    .DESCRIPTION
        Resolves the OpenSSH server directories, configuration files, daemon
        binary, and authorized_keys file.

        By default, the authorized_keys path is selected according to the
        current execution context: administrators use the server-wide
        administrators_authorized_keys file, while normal users use
        .ssh\authorized_keys in their profile.

        When ForUser is supplied, the current execution context is ignored and
        the specified user's profile is used.

    .PARAMETER ForUser
        Optional username whose profile should contain the authorized_keys file.
        The profile is located with Get-UserHomeDirectory.

    .OUTPUTS
        PSCustomObject

    .EXAMPLE
        Get-SshPaths

        Returns OpenSSH paths for the current administrator or normal user.

    .EXAMPLE
        Get-SshPaths -ForUser "jdoe"

        Returns paths for the jdoe user's .ssh\authorized_keys file.
    #>
    param(
        [ValidateNotNullOrEmpty()]
        [string]$ForUser
    )

    # Set the server-wide data directory and default Windows OpenSSH binary.
    $SshDataDir = Join-Path $env:ProgramData 'ssh'
    $SshdBinary = Join-Path $env:WINDIR 'System32\OpenSSH\sshd.exe'

    # Prefer the binary registered with the sshd service, including MSI installs.
    $Service = Get-CimInstance -ClassName Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue
    if ($Service -and $Service.PathName) {
        # Extract the executable path from either a quoted or unquoted service path.
        $Binary = if ($Service.PathName -match '^\s*"([^"]+)"') {
            $Matches[1]
        }
        else {
            ($Service.PathName.Trim() -split '\s+', 2)[0]
        }

        # Only use the service binary when its path points to an existing file.
        if (Test-Path -LiteralPath $Binary -PathType Leaf) { $SshdBinary = $Binary }
    }

    # An explicit user takes priority over the current process's privilege level.
    if ($ForUser) {
        $UserHomeDirectory = Get-UserHomeDirectory -Username $ForUser
        if (-not $UserHomeDirectory) {
            throw "Unable to find the user profile for '$ForUser'."
        }

        $SshHome = Join-Path $UserHomeDirectory '.ssh'
        $SshAuthorizedKeysFile = Join-Path $SshHome 'authorized_keys'
    }
    elseif (
        ([Security.Principal.WindowsPrincipal]::new(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    ) {
        # Elevated administrators use the server-wide authorized keys file.
        $SshHome = $SshDataDir
        $SshAuthorizedKeysFile = Join-Path $SshHome `
            'administrators_authorized_keys'
    }
    else {
        # Normal users use authorized_keys in their own profile.
        $SshHome = Join-Path $env:USERPROFILE '.ssh'
        $SshAuthorizedKeysFile = Join-Path $SshHome 'authorized_keys'
    }

    # Return one object containing all server and user-specific OpenSSH paths.
    [pscustomobject]@{
        SshDataDir            = $SshDataDir
        SshHome               = $SshHome
        SshMainConfig         = Join-Path $SshDataDir 'sshd_config'
        SshConfigDir          = Join-Path $SshDataDir 'sshd_config.d'
        SshAuthorizedKeysFile = $SshAuthorizedKeysFile
        SshdBinary            = $SshdBinary
    }
}

function Set-SshFirewallRuleAllowIp {
    <#
    .SYNOPSIS
        Configures the allowed remote addresses for the Windows OpenSSH firewall rule.

    .DESCRIPTION
        Adds supplied IP addresses to the OpenSSH-Server-In-TCP firewall rule.
        Use ResetAllowedRemoteAddresses to replace the existing addresses
        instead.

        Addresses can be supplied directly or read from the
        SshAllowIpAddresses property of a JSON file.

    .PARAMETER IpAddresses
        One or more IPv4 or IPv6 addresses to allow. This parameter is mutually
        exclusive with JsonFile.

    .PARAMETER JsonFile
        Path to a JSON file containing an SshAllowIpAddresses property with at
        least one IPv4 or IPv6 address. This parameter is mutually exclusive
        with IpAddresses.

    .PARAMETER ResetAllowedRemoteAddresses
        Replaces the existing allowed addresses with the supplied addresses.
        When omitted, the supplied addresses are added to the existing
        addresses.

    .EXAMPLE
        Set-SshFirewallRuleAllowIp -IpAddresses "192.0.2.10", "2001:db8::10"

        Adds the two addresses while preserving the current allowed addresses.

    .EXAMPLE
        Set-SshFirewallRuleAllowIp `
            -JsonFile "C:\Config\ssh.json" `
            -ResetAllowedRemoteAddresses

        Replaces the allowed addresses with those in the JSON file's
        SshAllowIpAddresses property.
    #>
    [CmdletBinding(DefaultParameterSetName = "IpAddresses")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "IpAddresses")]
        [ValidateNotNullOrEmpty()]
        [string[]]$IpAddresses,
        [Parameter(Mandatory = $true, ParameterSetName = "JsonFile")]
        [ValidateNotNullOrEmpty()]
        [string]$JsonFile,
        [switch]$ResetAllowedRemoteAddresses
    )

    # Find the Windows OpenSSH inbound firewall rule.
    $SshFirewallRule = Get-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -ErrorAction SilentlyContinue
    if (-not $SshFirewallRule) {
        throw "Firewall rule OpenSSH-Server-In-TCP was not found."
    }

    # Read the rule's current allowed remote addresses.
    $CurrentRemoteAddresses = @(
        Get-NetFirewallAddressFilter `
            -AssociatedNetFirewallRule $SshFirewallRule |
        Select-Object -ExpandProperty RemoteAddress |
        Sort-Object -Unique
    )

    # When a JSON file is supplied, load addresses from its configured property.
    if ($PSCmdlet.ParameterSetName -eq "JsonFile") {
        $JsonContent = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json
        $IpAddresses = @($JsonContent.SshAllowIpAddresses)

        if ($IpAddresses.Count -eq 0) {
            throw "JsonFile must contain an SshAllowIpAddresses property with at least one IP address."
        }
    }

    # Validate and normalize all supplied IPv4 and IPv6 addresses.
    $NormalizedIpAddresses = foreach ($IpAddress in $IpAddresses) {
        if ([string]::IsNullOrWhiteSpace($IpAddress)) {
            throw "SshAllowIpAddresses cannot contain an empty IP address."
        }

        $ParsedAddress = $null
        if (-not [System.Net.IPAddress]::TryParse($IpAddress, [ref]$ParsedAddress)) {
            throw "Invalid IP address: '$IpAddress'"
        }

        $ParsedAddress.ToString()
    }

    # Remove duplicate supplied addresses.
    $NormalizedIpAddresses = $NormalizedIpAddresses | Select-Object -Unique

    # Preserve current addresses unless a reset was explicitly requested.
    if (-not $ResetAllowedRemoteAddresses) {
        $NormalizedIpAddresses = @(
            $CurrentRemoteAddresses
            $NormalizedIpAddresses
        ) | Select-Object -Unique
    }

    # Apply the final address set to the OpenSSH inbound firewall rule.
    Set-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -RemoteAddress $NormalizedIpAddresses `
        -Enabled True
}

function Install-WindowsOpenSSHServer {

    # Resolve server paths before checking privileges or changing system state.
    $SshPaths = Get-SshPaths

    # Require an elevated administrator because this function changes Windows services and ProgramData.
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)

    if (-not $Principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )) {
        throw "This function must be run as Administrator."
    }

    Write-Host "Installing OpenSSH Server..."

    # Install the Windows OpenSSH Server capability only when it is absent.
    $Capability = Get-WindowsCapability -Online `
        -Name "OpenSSH.Server~~~~0.0.1.0"

    if ($Capability.State -ne "Installed") {
        Add-WindowsCapability -Online `
            -Name "OpenSSH.Server~~~~0.0.1.0" |
        Out-Null
    }

    # Start sshd now because its initialization creates required runtime files and defaults.
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd -ErrorAction SilentlyContinue

    # Ensure Administrators belongs to the group allowed by the base SSH policy.
    $windows_ssh_group = "OpenSSH Users"
    $member = "Administrators"

    if (-not (Get-LocalGroupMember -Group $windows_ssh_group | Where-Object Name -Match "\\Administrators$")) {
        Add-LocalGroupMember -Group $windows_ssh_group -Member $member
    }

    # Create the drop-in configuration directory used by sshd.
    if (-not (Test-Path $SshPaths.SshConfigDir)) {
        New-Item -Path $SshPaths.SshConfigDir -ItemType Directory -Force |
        Out-Null
    }

    # Create the administrator key file selected by the elevated path resolver.
    if (-not (Test-Path $SshPaths.SshAuthorizedKeysFile)) {
        New-Item -Path $SshPaths.SshAuthorizedKeysFile -ItemType File -Force |
        Out-Null
    }

    # Remove inherited permissions and grant only Administrators and SYSTEM full control.
    & icacls.exe $SshPaths.SshAuthorizedKeysFile /inheritance:r `
        /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F'

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure authorized_keys permissions."
    }

    # Enable loading *.conf files from sshd_config.d when not already configured.
    if (-not (Test-Path $SshPaths.SshMainConfig)) {
        throw "SSH configuration file not found: $SshPaths.SshMainConfig"
    }

    $Config = Get-Content -Path $SshPaths.SshMainConfig -Raw

    if ($Config -notmatch '(?im)^\s*Include\s+.*sshd_config\.d') {
        Write-Host "Adding sshd_config.d Include directive..."

        # Preserve the original file before modifying it
        Copy-Item $SshPaths.SshMainConfig "$SshPaths.SshMainConfig.bak" -Force

        $NewConfig = 'Include sshd_config.d/*.conf' + "`r`n" + $Config

        # Write UTF-8 without BOM
        $Encoding = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText(
            $SshPaths.SshMainConfig,
            $NewConfig,
            $Encoding
        )
    }

    # Create the base drop-in that contains the required authentication policy.
    $BaseConfigFile = Join-Path $SshPaths.SshConfigDir "15_sshd_base.conf"
    if (-not (Test-Path $BaseConfigFile)) {
        Write-Host "Creating base SSH configuration file..."
        New-Item -Path $BaseConfigFile -ItemType File -Force | Out-Null
    }

    # Put each required directive before any conflicting active directive.
    $BaseConfig = Get-Content -Path $BaseConfigFile -Raw

    # Define the exact policy directives and values expected by this installer.
    $RequiredDirectives = @(
        [pscustomobject]@{
            Name  = "PasswordAuthentication"
            Value = "no"
            Line  = "PasswordAuthentication no"
        },
        [pscustomobject]@{
            Name  = "PubkeyAuthentication"
            Value = "yes"
            Line  = "PubkeyAuthentication yes"
        },
        [pscustomobject]@{
            Name  = "UseDNS"
            Value = "no"
            Line  = "UseDNS no"
        },
        [pscustomobject]@{
            Name  = "AllowGroups"
            Value = "`"$windows_ssh_group`""
            Line  = "AllowGroups `"$windows_ssh_group`""
        }
    )

    # Determine which first-occurrence directives need to be prepended.
    $DirectivesToPrepend = [Collections.Generic.List[string]]::new()
    foreach ($Directive in $RequiredDirectives) {
        $NamePattern = [regex]::Escape($Directive.Name)
        $FirstDirective = [regex]::Match(
            $BaseConfig,
            "(?im)^[ \t]*$NamePattern\b[^\r\n]*"
        )
        $ValuePattern = [regex]::Escape($Directive.Value)
        $IsRequiredValue = $FirstDirective.Success -and
        $FirstDirective.Value -match
        "(?i)^[ \t]*$NamePattern[ \t]+$ValuePattern[ \t]*(?:#.*)?$"

        if (-not $IsRequiredValue) {
            $DirectivesToPrepend.Add($Directive.Line)
        }
    }

    # OpenSSH uses the first active value, so corrected directives must precede conflicts.
    if ($DirectivesToPrepend.Count -gt 0) {
        $NewBaseConfig = (
            ($DirectivesToPrepend -join "`r`n") + "`r`n" + $BaseConfig
        )
        $Encoding = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText(
            $BaseConfigFile,
            $NewBaseConfig,
            $Encoding
        )
    }


    # Ask sshd to parse the complete configuration before reporting success.
    Write-Host "Validating SSH configuration..."

    & $SshPaths.SshdBinary -t -f $SshPaths.SshMainConfig

    if ($LASTEXITCODE -ne 0) {
        throw "SSH configuration validation failed. Review $SshPaths.SshMainConfig"
    }

    Write-Host "Windows OpenSSH Server installation complete." `
        -ForegroundColor Green
}

function Add-AuthorizedKey {
    <#
    .SYNOPSIS
        Adds an SSH public key to the selected authorized_keys file.

    .PARAMETER ForUser
        Optional user whose authorized_keys file should be updated. When omitted,
        Get-SshPaths selects the path for the current administrator or user.

    .PARAMETER PublicKey
        Public key text to add. Mutually exclusive with PublicKeyFile.

    .PARAMETER PublicKeyFile
        Path to a file containing the public key. Mutually exclusive with
        PublicKey.
    #>
    [CmdletBinding(DefaultParameterSetName = "PublicKey")]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$ForUser,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "PublicKey"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PublicKey,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "PublicKeyFile"
        )]
        [ValidateScript({
                Test-Path -LiteralPath $_ -PathType Leaf
            })]
        [string]$PublicKeyFile
    )

    # Resolve the authorized_keys path for an explicit user or the current user.
    if (-not $ForUser) {
        $SshPaths = Get-SshPaths
    }
    else {
        $SshPaths = Get-SshPaths -ForUser $ForUser
    }

    # Read each non-empty key entry from the selected input parameter.
    if ($PSCmdlet.ParameterSetName -eq "PublicKeyFile") {
        $PublicKeys = @(
            Get-Content -LiteralPath $PublicKeyFile |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
    else {
        $PublicKeys = @(
            $PublicKey -split '\r?\n' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    if ($PublicKeys.Count -eq 0) {
        throw "No public keys were provided."
    }

    # Remove duplicates within the supplied input using case-sensitive comparison.
    $SeenKeys = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $PublicKeys = @(
        $PublicKeys | Where-Object { $SeenKeys.Add($_) }
    )

    # Create the selected SSH directory and authorized_keys file when missing.
    if (-not (Test-Path -LiteralPath $SshPaths.SshHome -PathType Container)) {
        New-Item -Path $SshPaths.SshHome -ItemType Directory -Force |
        Out-Null
    }

    if (-not (Test-Path -LiteralPath $SshPaths.SshAuthorizedKeysFile -PathType Leaf)) {
        New-Item -Path $SshPaths.SshAuthorizedKeysFile -ItemType File -Force |
        Out-Null
    }

    # Add each key only when its case-sensitive entry is not already present.
    $ExistingKeys = @(Get-Content -LiteralPath $SshPaths.SshAuthorizedKeysFile)
    $PublicKeysToAdd = @(
        $PublicKeys | Where-Object { $_ -cnotin $ExistingKeys }
    )
    if ($PublicKeysToAdd.Count -gt 0) {
        $ExistingContent = Get-Content `
            -LiteralPath $SshPaths.SshAuthorizedKeysFile -Raw

        if ($ExistingContent -and
            -not $ExistingContent.EndsWith([Environment]::NewLine)
        ) {
            Add-Content -LiteralPath $SshPaths.SshAuthorizedKeysFile -Value ""
        }

        Add-Content `
            -LiteralPath $SshPaths.SshAuthorizedKeysFile `
            -Value $PublicKeysToAdd
    }

    # Restrict the server-wide administrators authorized_keys file.
    if ($SshPaths.SshAuthorizedKeysFile -eq
        (Join-Path $SshPaths.SshDataDir "administrators_authorized_keys")
    ) {
        # Windows OpenSSH rejects administrator key files with overly broad ACLs.
        & icacls.exe $SshPaths.SshAuthorizedKeysFile /inheritance:r `
            /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F'

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to configure authorized_keys permissions."
        }
    }
}
