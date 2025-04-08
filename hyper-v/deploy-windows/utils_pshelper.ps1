function Show-OptionalUserExitAndContinue {
    [CmdletBinding()]
    param (
        [string]$Message = "Warning",
        [Int64]$timeout = 11
    )

    # Display the warning message in red

    Write-Host $Message -ForegroundColor Red
    Write-Host "Press the enter key to exit program or wait 10 seconds to continue."

    # Check for the Enter key in a loop
    while ((++$counter) -lt $timeout) {
        Start-Sleep -Seconds 1
        write-host "$($timeout - $counter) seconds left before continuing..."
        if ([Console]::KeyAvailable) {
            # A key was pressed, check if it's the Enter key
            $Key = [Console]::ReadKey($true).Key

            if ($Key -eq [ConsoleKey]::Enter) {
                Write-Host "Enter key pressed, quiting execution..."
                Throw "User requested exit"
            }
        }
    }
}