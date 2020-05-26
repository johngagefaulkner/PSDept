function Wait-Condition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Condition,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$CheckEvery = 30,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Timeout = 600
    )

    $ErrorActionPreference = 'Stop'
    

    try {
        # Start the timer
        $timer = [Diagnostics.Stopwatch]::StartNew()

        # Keep in the loop while the item is false
        Write-Verbose -Message "Waiting for condition..."
        while (-not (& $Condition)) {
            $logger.informational("Waiting for condition... $Condition")
            Write-Verbose -Message "Waiting for condition..."
            # If the timer has waited greater than or equal to the timeout, throw an exception exiting the loop
            if ($timer.Elapsed.TotalSeconds -ge $Timeout) {
                $logger.error("Timeout exceeded. Giving up... $Condition")
                throw "Timeout exceeded. Giving up..."
            }
            # Stop the loop every $CheckEvery seconds
            Start-Sleep -Seconds $CheckEvery
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $timer.Stop()
    }
    
}