function Show-OptionalUserExitAndContinue {
    [CmdletBinding()]
    param (
        [string]$Message = "Message",
        [Int64]$timeout = 10,
        [ValidateSet("Green", "Yellow", "Red")]
        [string]$color = "Yellow"
    )

    # Display the warning message in red

    Write-Host $Message -ForegroundColor $color
    Write-Host "Press the ENTER key to exit program, SPACE key to continue, or wait $timeout seconds to automatically continue."

    # Check for the Enter key in a loop
    while ((++$counter) -lt $timeout) {
        # Countdown logic and display)
        if ($($counter) -eq 1) { write-host("$timeout ") -NoNewline } # Downside of initialization of counter in the while loop declaration
        Start-Sleep -Seconds 1
        write-host "$($timeout - $counter)  " -NoNewline
        if ($($timeout - $counter) -eq 1) { write-host("`r") }

        if ([Console]::KeyAvailable) {
            # A key was pressed, check if it's the Enter and Spacebar key
            $Key = [Console]::ReadKey($true).Key

            if ($Key -eq [ConsoleKey]::Enter) {
                write-host("`r")
                Write-Host "ENTER key pressed, quiting execution..."
                Throw "User requested exit"
            }
            if ($Key -eq [ConsoleKey]::Spacebar) {
                write-host("`r")
                Write-Host "SPACE key pressed, continue execution..."
                return
            }
        }
    }
}

function Show-OptionalUserCountdownContinue {
    [CmdletBinding()]
    param (
        [string]$Message = "Message",
        [Int64]$timeout = 10,
        [ValidateSet("Green", "Yellow", "Red")]
        [string]$color = "Yellow"
    )
    Write-Host $Message -ForegroundColor $color
    Write-Host "Press SPACE to continue (or wait for): " -ForegroundColor $color -NoNewline
   
    $counter = 0
    while (($counter) -lt $timeout) {
        # Countdown logic and display)
        write-host "$($timeout - $counter)  " -NoNewline
        if ($($timeout - $counter) -eq 1) { write-host("`r") }
        Start-Sleep -Seconds 1
        $counter++

        if ([Console]::KeyAvailable) {
            # A key was pressed, check if it's the spacebar key
            $Key = [Console]::ReadKey($true).Key
            if ($Key -eq [ConsoleKey]::Spacebar) {
                write-host("`r")
                Write-Host "SPACE key pressed, continue execution..."
                return
            }
        }
    }
}

function Show-UserKeyPressToContinue {
    param (
        [string]$Message = "Message",
        [ValidateSet("Green", "Yellow", "Red")]
        [string]$color = "Yellow"
    )
    Write-Host $Message -ForegroundColor $color
    Write-Host "Press any key to continue." -ForegroundColor $color -NoNewline
    [void][System.Console]::ReadKey($true)
}