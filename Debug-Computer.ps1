function Debug-Computer {
    <#
    .SYNOPSIS
        Grabs event logs and other reports.

    .DESCRIPTION
        Grabs stability metrics,DumpSettings,cleanShutdowns,dirtyShutdowns, and Bluescreen events, Recent Error , groups the types of errors together

    .PARAMETER StabilityThreshhold
        Marks the stability threshhold at which you want to start search logs on

    .PARAMETER StartTime
        Start search logs this many days ago

    .PARAMETER EndTime
        End searching for logs on this date

    .PARAMETER LowStability
        Forces the search of logs by saying there is low stability

    .INPUTS
        None

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Debug-Computer

    .EXAMPLE
        Debug-Computer -StabilityThreshhold 4

    .EXAMPLE
        Debug-Computer -StabilityThreshhold 4 -StartTime -76

    .EXAMPLE
        Debug-Computer -StartTime -23 -LowStability

    .EXAMPLE
        Debug-Computer -StartTime -500 -EndTime -25 -LowStability
    
    .EXAMPLE
        Debug-Computer -StartTime -1 -EndTime 0 -LowStability

    .LINK
        https://devblogs.microsoft.com/scripting/use-powershell-to-determine-computer-reliability/

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Threshhold')]
    param (       
        [Parameter(Mandatory = $false,Position = 0,ParameterSetName = "Threshhold")]
        [int]$StabilityThreshhold = 7,

        [Parameter(Mandatory = $false,Position = 1)]
        [int]$StartTime = -14,

        [Parameter(Mandatory = $false,Position = 2)]
        $EndTime = (Get-Date),

        [Parameter(Mandatory = $false,ParameterSetName = "Force")]
        [switch]$LowStability
    )
    
    begin {
        # Get Current Stability Metrics
        $stabilityMetrics = (Get-Ciminstance -ClassName "Win32_ReliabilityStabilityMetrics" | Measure-Object -Average -Maximum -Minimum -Property systemStabilityIndex)
        if ([double]($stabilityMetrics.Average) -gt $stabilityThreshhold ) {
            $LowStability = $true
        } else {
            $currentMetrics = "Current Stability Index:($([math]::Round($stabilityMetrics.Average,2))/10)"
        }

        # Use this function to get what items are having trouble and how much counts
        Function Get-SortedReliabilityRecords {
            Param ([string]$computer = ".")
            Get-CimInstance -ClassName "Win32_ReliabilityRecords" |
            Group-Object -Property sourcename, eventidentifier -NoElement |
            Sort-Object -Descending count | Select-Object -Property count, @{Label = "Source"; Expression = { $_.values[0] } },@{Label = "eventidentifier"; Expression = { $_.values[1] } } |
            Format-Table -Wrap -AutoSize
        } 

        function Get-DumpSettings {
            param(
                $regdata = (Get-ItemProperty -path "HKLM:\System\CurrentControlSet\Control\CrashControl")
            )
        
            $dumpsettings = @{}
            $dumpsettings.CrashDumpMode = switch ($regdata.CrashDumpEnabled) {
                1 { if ($regdata.FilterPages) { "Active Memory Dump" } else { "Complete Memory Dump" } }
                2 {"Kernel Memory Dump"}
                3 {"Small Memory Dump"}
                7 {"Automatic Memory Dump"}
                default {"Unknown"}
            }
            
            $dumpsettings.DumpFileLocation = $regdata.DumpFile
            [bool]$dumpsettings.AutoReboot = $regdata.AutoReboot
            [bool]$dumpsettings.OverwritePrevious = $regdata.Overwrite
            [bool]$dumpsettings.AutoDeleteWhenLowSpace = -not $regdata.AlwaysKeepMemoryDump
            [bool]$dumpsettings.SystemLogEvent = $regdata.LogEvent
            
            return $dumpsettings
        }

        $eventValues = @{}

        $eventKeywords = @(
            "AuditFailure",
            "AuditSuccess",
            "CorrelationHint2",
            "EventLogClassic",
            "Sqm",
            "WdiDiagnostic",
            "WdiContext",
            "ResponseTime",
            "None"
        )

        foreach ($eventKeyword in $eventKeywords){
          [string]$value = ([System.Diagnostics.Eventing.Reader.StandardEventKeywords]::$($eventKeyword)).value__
          $eventValues.add("$eventKeyword",$value)
        }

        $Levels = @{
            Verbose       = 5
            Informational = 4
            Warning       = 3
            Error         = 2
            Critical      = 1
            LogAlways     = 0
        }

        $cleanShutdowns = @{
            LogName = 'System'
            ProviderName ='EventLog'
            #Path =<String[]>
            Keywords = $eventValues['EventLogClassic']
            ID = '6006'
            Level = "$($Levels.Informational)"
            StartTime = (Get-Date).AddDays($StartTime)
            #EndTime =$EndTime
            #UserID =<SID>
            #Data =''
        }

        $dirtyShutdowns = @{
            LogName = 'System'
            ProviderName = 'EventLog'
            #Path =<String[]>
            Keywords = $eventValues['EventLogClassic']
            ID = '6008'
            Level = "$($Levels.Error)"
            StartTime = (Get-Date).AddDays($StartTime)
            #EndTime =$EndTime
            #UserID =<SID>
            #Data =''
        }

        $blueScreenEvents = @{
            LogName = 'application'
            ProviderName ='Windows Error*'
            #Path =<String[]>
            Keywords = $eventValues['EventLogClassic']
            ID ='6008'
            Level = "$($Levels.Error)"
            StartTime = (Get-Date).AddDays($StartTime)
            #EndTime =$EndTime
            #UserID =<SID>
            #Data =''
        }

    }    
    process {
        if ($lowStability) {
            [PSCustomObject]@{
                StabilityMetrics = [math]::Round($stabilityMetrics.Average,2)
                StabilityThreshhold = $stabilityThreshhold
            } | Format-Table -AutoSize

            Write-Output "Current Crash Logging Settings"
            Get-DumpSettings

            Get-SortedReliabilityRecords

            # Group Application errors
            $applicationError = Get-CimInstance -ClassName Win32_ReliabilityRecords -Filter "SourceName = 'application error'" | 
            Select-Object ProductName | Group-Object -Property productname -NoElement | Sort-Object count -Descending

            # Get Time generated by top three
            Write-output "Current 'Recent Error' data shows you the applications that have had errors recently"
            foreach ($Program in $applicationError.name) {
                $timegenerated = Get-CimInstance -ClassName Win32_ReliabilityRecords -Filter "SourceName = 'application error' AND ProductName = '$Program'" |
                Select-Object timegenerated | Sort-Object name,timegenerated -Descending
                foreach ($time in $timegenerated){
                    [PSCustomObject]@{
                        Application   = $Program
                        TimeGenerated = $time.timegenerated
                    }
                } 
            }
            
            $events = @(
                @{Name = "Blue Screen Events" ; Action = Invoke-Command { Get-WinEvent -FilterHashtable $blueScreenEvents -ea SilentlyContinue | Where-Object -Property Message -Match 'BlueScreen' | ft -auto -wrap} ;  },
                @{Name = "Dirty Shutdown Events" ; Action = Invoke-Command { Get-WinEvent -FilterHashtable $dirtyShutdowns -ea SilentlyContinue | Where-Object -Property Message -Match 'was unexpected'| ft -auto -wrap} ;  },
                @{Name = "Clean Shutdown Events" ; Action = Invoke-Command { Get-WinEvent -FilterHashtable $cleanShutdowns -ea SilentlyContinue | ft -auto -wrap} ;  }
            )

            foreach ($event in $events){
                if ($null -ne $event.action){
                "------------------------------------"
                ""
                    Write-Output "Aggregating $($event.name)"
                    $event.action
                }
            }
        }
    }
    
    end {
        ""
        $currentMetrics
    }
}