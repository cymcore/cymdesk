function Show-OptionalUserExitAndContinue {
    [CmdletBinding()]
    param (
        [string]$Message = "Warning",
        [Int64]$timeout = 10
    )

    # Display the warning message in red

    Write-Host $Message -ForegroundColor Red
    Write-Host "Press the ENTER key to exit program, SPACE key to continue, or wait $timeout seconds to automatically continue."

    # Check for the Enter key in a loop
    while ((++$counter) -lt $timeout) {
        # Countdown logic and display)
        if ($($counter) -eq 1) { write-host("$timeout ") -NoNewline } # Downside of initialization of counter in the while loop declaration
        Start-Sleep -Seconds 1
        write-host "$($timeout - $counter)  " -NoNewline
        if ($($timeout - $counter) -eq 1) { write-host("`r") }

        if ([Console]::KeyAvailable) {
            # A key was pressed, check if it's the Enter key
            $Key = [Console]::ReadKey($true).Key

            if ($Key -eq [ConsoleKey]::Enter) {
                Write-Host "Enter key pressed, quiting execution..."
                Throw "User requested exit"
            }
            if ($Key -eq [ConsoleKey]::Spacebar) {
                Write-Host "Space key pressed, continue execution..."
                return
            }
        }
    }
}