
"start" | Out-File -FilePath "c:\temp\verimark.txt" -Append
# Give USB time to enumerate after wake from sleep
Start-Sleep -Seconds 7
# Find Verimark fingerprint devices
$device = Get-PnpDevice |
    Where-Object {
        $_.FriendlyName -match 'Verimark|Fingerprint'
    }

if (-not $device) {
    Write-Host "No Verimark fingerprint device found."
    return
}

foreach ($d in $device) {
    Write-Host "Restarting device: $($d.FriendlyName)"

    Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
    Start-Sleep -Seconds 3
    Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
}

"end" | Out-File -FilePath "c:\temp\verimark.txt" -Append