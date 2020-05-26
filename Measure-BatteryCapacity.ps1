function Measure-BatteryCapacity {
    <#
    .SYNOPSIS
        Measure the battery capacity

    .DESCRIPTION
        Measure the battery capacity and will let you know if a battery is below a certain percentage for its charging ability .
        It will then output a report if it is or you can force a report. Also it will tell you which battery and its serial number.

    .PARAMETER Degradation
        Int value of 30-90 for how low the battery can go before a report is generated

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .PARAMETER ForceReport
        Switch to force a report
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Measure-BatteryCapacity

    .EXAMPLE
        Measure-BatteryCapacity -Degradation 30

    .EXAMPLE
        Measure-BatteryCapacity -ForceReport

    .EXAMPLE
        Measure-BatteryCapacity -Degradation 30 -ForceReport

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(30, 90)]
        [int]$Degradation = "68",

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp",

        [switch]$ForceReport
    )
    begin {
        # Add Logging block
        try {
            if (!("PSLogger" -as [type])) {
                $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
                ."\\Server\Path\Here\Logging.ps1"
                $logger = [PSLogger]::new($logPath, $callingScript)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        # First block to add/change stuff in
        try {
            $batteries = @(Get-CimInstance -ClassName "BatteryStatus" -Namespace "ROOT\WMI")
            $currentBattery = 0
            $replaceBatteryCount = 0
            $replaceBattery = $false 
       
            Function Get-BatteryState {
                param($Battery = (Get-CimInstance -Classname "Win32_Battery" -ea 0).BatteryStatus)
                if ($battery) {
                    switch ($battery) {
                        1 { "Battery is discharging"; break }
                        2 { "The system has access to AC so no battery is being discharged. However, the battery is not necessarily charging."; break }
                        3 { "Fully Charged"; break }
                        4 { "Low"; break }
                        5 { "Critical"; break }
                        6 { "Charging"; break }
                        7 { "Charging and High"; break }
                        8 { "Charging and Low"; break }
                        9 { "Charging and Critical"; break }
                        10 { "Undefined"; break }
                        11 { "Partially Charged"; break }
                        default { "Not a known Status" }
                    }
                }
            }            

        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    process {
    
        try {
            if ((Get-CimInstance -ClassName 'Win32_ComputerSystem' -Property PCSystemType).PCSystemType -eq 2) {

                if ((Get-CimInstance -Classname "Win32_Battery").count -ne 0) {

                    $battery = foreach ($battery in $batteries) {
                        $batteryInformation = (Get-CimInstance -Classname "Win32_Battery")[$currentBattery]
                        $designedCapacity = (Get-CimInstance -Classname "CIM_Battery" -Namespace "root\CIMV2").DesignCapacity[$currentBattery]
                        $fullCharge = (Get-CimInstance -Namespace "root\wmi" -ClassName "batteryfullchargedcapacity").FullChargedCapacity[$currentBattery]
    
                        if (($null -eq $designedCapacity) -or ($null -eq $fullCharge)) {
                            $logger.warning("Battery[$CurrentBattery] may not be present")
                            Write-Output "Battery[$CurrentBattery] may not be present" 
                        }
                        else {
                            # Make sure battery is not over 100%
                            [int]$currentBatteryCapacity = ($FullCharge / $DesignedCapacity) * 100
                            if ($currentBatteryCapacity -gt 100) {
                                $currentBatteryCapacity = 100
                            }
                        }
    
                        # Round battery percentage
                        $currentBatteryCapacity = [decimal]::round($currentBatteryCapacity)
    
                        # Compare current capacity to lowest allowable
                        if ($currentBatteryCapacity -le $Degradation) {
                            $logger.Alert("Battery[$CurrentBattery][Serial:$($batteryInformation.DeviceID)] capacity is at $($currentBatteryCapacity)%.")
                            Write-Host "Battery[$CurrentBattery][Serial:$($batteryInformation.DeviceID)] capacity is at $($currentBatteryCapacity)%." -ForegroundColor Red
    
                            $replaceBatteryCount++
                            $replaceBattery = $true
                        }
                        
                        # Battery check if status is not "OK" and grabs FRU/serial Number if bad
                        if ($batteryInformation.Status -notmatch "OK") {

                            $logger.warning("Current battery may have operational issues, Status is '$($batteryInformation.Status)'")
                            Write-Host "Current battery may have operational issues, Status is '$($batteryInformation.Status))'" -ForegroundColor red
                        
                            $logger.warning("Battery FRU is $($batteryInformation.DeviceID)")
                        }
                        else {
                            $logger.informational("Current battery should be operational, Status is '$($batteryInformation.Status)'")
                            Write-Host "Current battery should be operational, Status is '$($batteryInformation.Status)'" -ForegroundColor green
                        }
                        
                        if ($batteryInformation.Availability) {
                            $Availability = switch ($batteryInformation.Availability) {
                                1 { "Other"; break }
                                2 { "Unknown - Most likely on AC"; break }
                                3 { "Running or Full Power"; break }
                                4 { "Warning"; break }
                                10 { "Degraded"; break }
                                12 { "Install Error"; break }
                                17 { "Power Save - Warning"; break }
                                default { "Not a known Battery Availability" }
                            }
                        }

                        # Change current battery to next
                        $currentBattery++
                        
                        [PSCustomObject]@{
                            PSTypeName               = 'Battery.Information'
                            Message                  = 'Battery Information'
                            Description              = $batteryInformation.Description
                            Status                   = $batteryInformation.Status
                            State                    = Get-BatteryState -Battery $batteryInformation.BatteryStatus
                            Availability             = $Availability
                            CurrentBatteryCapacity   = "$currentBatteryCapacity%"
                            EstimatedChargeRemaining = $batteryInformation.EstimatedChargeRemaining
                            DeviceID                 = $batteryInformation.DeviceID
                            ReplacementNeeded        = $replaceBattery
                            BatteryCount             = "$currentBattery of $($batteries.count)"
                        }
                    }
                    $logger.informational($battery)
                    $battery
                }
                else {
                    $logger.warning("Current device is a $computerType, but there is no battery detected")                
                    Write-Host "Current device is a $computerType, but there is no battery detected" -ForegroundColor red
                }
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {

        if ($replaceBattery -or $ForceReport) {
            $logger.Alert("A New battery may be needed")
            Write-Host "A New battery may be needed" -ForegroundColor Red 
            POWERCFG -batteryreport -output "$home\desktop\battery-report.html" ; continue
        }

        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        #$logger.Remove()
        
    }
}
