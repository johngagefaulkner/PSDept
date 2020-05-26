function Test-CPU {
    <#
    .SYNOPSIS
        Starts the cpu benchmarking.

    .DESCRIPTION
        Runs a mathematical computation against each core of the cpu causing a rise in usage.
        Once completed for the alloted time, the test, will stop the computation and give you chassis temp results.

    .PARAMETER Minutes
        The amount of minutes you want to run the benchmarking. Max of 10 minutes

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Test-CPU
    
    .EXAMPLE
        Test-CPU -Minutes 9

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateRange (1,10)]
        [ValidateNotNullOrEmpty()]
        [int]$Minutes,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Informational("Starting CPU Stress Testing...")

        $script:HighTemp = 0
        $script:LowTemp = 0
        $script:NumberOfTemps = 0

        function Get-Temperature {
            $thermalZone = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi"
            $returnTemp = @()

            # Process temps
            foreach ($temp in $thermalZone.CurrentTemperature) {
                $currentTempKelvin = ($temp / 10)
                $currentTempCelsius = [math]::round($currentTempKelvin - 273.15)
                $currentTempFahrenheit = [math]::round((9 / 5) * $currentTempCelsius + 32)
                $returnTemp += "$currentTempCelsius" + " °C | " + "$currentTempFahrenheit" + " °F"
                $script:NumberOfTemps = ($returnTemp).count
            }
            foreach ($return in $returnTemp) {
                if ($return -ge "50") {
                    write-host "$return" -ForegroundColor Red
                    $script:HighTemp++
                }
                else {
                    $script:LowTemp++
                }
            }
        }

        # Test stress CPU
        function Test-StressCPU {
            ForEach ($core in 1..$env:NUMBER_OF_PROCESSORS) {
                [void](start-job -Name "CPU$core" -ScriptBlock {
                    $result = 1;
                    foreach ($loopnumber in 1..2147483647) {
                        $result = 1;
                        foreach ($number in 1..2147483647) {
                            $result = $result * $number
                        }
                        $result
                    }
                })
            }
        }
    }
    
    process {
        Write-Warning -Message "Stress Testing CPU in Progress..."
        #Runs the actual functions and keeps track of the timeout period
        $timeout = new-timespan -Minutes $Minutes
        $sw = [diagnostics.stopwatch]::StartNew()
        Test-StressCPU
        while ($sw.elapsed -lt $timeout) {
            #Clear-Host
            Get-Temperature         
            start-sleep -Seconds 60
        }

        $cpuJobs = Get-Job -Name "CPU*"
        foreach ($job in $cpuJobs) {
            Stop-Job -Name $job.name
            Remove-Job -Name $job.name
        }
    }
    
    end {
        Write-Verbose -message "CPU Stress Test Complete..."
        $logger.Informational("CPU Stress Test Complete...")
        $half = (($Minutes*4)/2)
        if ($HighTemp -gt $half){
            Write-Output "Laptop chassis temperatures rose to/above 50°C for $((($HighTemp/$script:NumberOfTemps)/($Minutes*4))*100)% of the time"
        }else {
            Write-Output "Laptop chassis temperatures stayed below 50°C for $((($LowTemp/$script:NumberOfTemps)/($Minutes*4))*100)% of the time"
        }
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}