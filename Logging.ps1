Class PsLogger {
    hidden $loggingScript =
    {
        
        function Start-Logging {
            $loggingTimer = new-object Timers.Timer
            $action = { logging }
            $loggingTimer.Interval = 1000
            $null = Register-ObjectEvent -InputObject $loggingTimer -EventName elapsed -Sourceidentifier loggingTimer -Action $action
            $loggingTimer.start()
        }
    
        function logging {
            $sw = $logFile.AppendText()
            while (-not $logEntries.IsEmpty) {
                $entry = ''
                $null = $logEntries.TryDequeue([ref]$entry)
                $sw.WriteLine($entry)
            }
            $sw.Flush()
            $sw.Close()
        }
        $logFile = New-Item -ItemType File -Name "$ExecutingScript`_$([DateTime]::UtcNow.ToString(`"yyyyMMddTHHmmssZ`")).log" -Path $logLocation
    
        Start-Logging
    }
    hidden $loggingRunspace = [runspacefactory]::CreateRunspace()
    hidden $logEntries = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    hidden $logLocation = "C:\Temp"
    hidden $ExecutingScript = "test"
    
    PsLogger([string]$logLocation, [string]$ExecutingScript) {
        $this.logLocation = $logLocation
        $this.ExecutingScript = $ExecutingScript

        # Check for and build log path
        if (!(Test-Path -Path $this.logLocation)) {
            [void](New-Item -path $this.logLocation -ItemType directory -force)
        }

        # Start Logging runspace
        $this.StartLogging()
    }

    Emergency([string]$message) {
        $this.LogMessage($message, "Emergency")
    }

    Alert([string]$message) {
        $this.LogMessage($message, "Alert")
    }

    Critical([string]$message) {
        $this.LogMessage($message, "Critical")
    }

    Error([string]$message) {
        $this.LogMessage($message, "Error")
    }

    Warning([string]$message) {
        $this.LogMessage($message, "Warning")
    }

    Notice([string]$message) {
        $this.LogMessage($message, "Notice")
    }

    Informational([string]$message) {
        $this.LogMessage($message, "Informational")
    }

    Debug([string]$message) {
        $this.LogMessage($message, "Debug")
    }
    
    hidden LogMessage([string]$message, [string]$severity) {
        $addResult = $false

        $funcName = (Get-PSCallStack).FunctionName[2]

        if ($funcName -eq "<ScriptBlock>") {
            $funcName = ""
        }

        $msg = $null

        while ($addResult -eq $false) {
            $msg = '<{0}> [{1}] {2} - {3}' -f [DateTime]::UtcNow.tostring('yyyy-MM-dd HH:mm:ssK'), $severity, $funcName, $message
            $addResult = $this.logEntries.TryAdd($msg)
        }

       #write-host "$msg"

    }

    hidden StartLogging() {
        $this.LoggingRunspace.ThreadOptions = "ReuseThread"
        $this.loggingRunspace.name = 'PSLogger'
        $this.LoggingRunspace.Open()
        $this.LoggingRunspace.SessionStateProxy.SetVariable("logEntries", $this.logEntries)
        $this.LoggingRunspace.SessionStateProxy.SetVariable("logLocation", $this.logLocation)
        $this.LoggingRunspace.SessionStateProxy.SetVariable("ExecutingScript", $this.ExecutingScript)
        $cmd = [PowerShell]::Create().AddScript($this.loggingScript)
      
        $cmd.Runspace = $this.LoggingRunspace
        $null = $cmd.BeginInvoke()
    }


    # Stop Method
    Stop() {
        $This.LoggingRunspace.Stop()
    }

    # Remove Method
    Remove() {
        Start-Sleep -Seconds 1
        $This.LoggingRunspace.close()
        $This.LoggingRunspace.Dispose()
        If ($This.LoggingRunspace) {
            $This.LoggingRunspace.close()
            $This.LoggingRunspace.Dispose()
        }
    }
 
    # Get Status Method
    [object]GetStatus() {
        return $This.LoggingRunspace.InvocationStateInfo
    }
}
