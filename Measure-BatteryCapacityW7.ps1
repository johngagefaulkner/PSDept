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
        [Parameter(Mandatory=$false)]
        [ValidateRange(30,90)]
        [int]$Degradation = "68",

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp",

        [switch]$ForceReport
    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath, $callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        
        $batteries = (Get-WMIObject -Class "BatteryStatus" -Namespace "ROOT\WMI")
        $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
        $currentBattery = 0
        $replaceBatteryCount = 0

        # Set Initial Battery Replacement Status 
        $ReplaceBattery = $false 

        $CompConfig = Get-WMIObject -Class 'Win32_ComputerSystem' -Property PCSystemType

        Function Get-BatteryState {
            param($Laptop = $env:computername)
            $batteryStatus = (Get-WMIObject -Class "Win32_Battery" -ea 0).BatteryStatus
            if ($batteryStatus) {
                switch ($batteryStatus) {
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
    
    process {
        if ($CompConfig.PCSystemType -eq 2) {
            # If there is a battery,check each battery
            if ((Get-WMIObject -Class "Win32_Battery").count -ne 0) {
                foreach ($battery in $batteries) {
                    $designedCapacity = (Get-WMIObject -Class "CIM_Battery" -Namespace "root\CIMV2").DesignCapacity[$currentBattery]
                    $fullCharge = (Get-CimInstance -namespace "ROOT\WMI" -Query "Select * from BatteryFullChargedCapacity").FullChargedCapacity[$currentBattery]
                    $batteryDeviceID = (Get-WMIObject -Class "Win32_Battery").Name
                    $batteryDeviceID = $batteryDeviceID.split(" ")[$currentBattery]

                    if (($null -eq $designedCapacity) -or ($null -eq $fullCharge)) {
                        $logger.notice("Battery[$CurrentBattery] may not be present")
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
                        $logger.notice("Battery[$CurrentBattery][Serial:$batteryDeviceID] capacity is at $($currentBatteryCapacity)%.")
                        Write-Host "Battery[$CurrentBattery][Serial:$batteryDeviceID] capacity is at $($currentBatteryCapacity)%." -ForegroundColor Red

                        $replaceBatteryCount++
                        $replaceBattery = $true
                    }
                
                    # Change current battery to next
                    $currentBattery++        
                }
            }

            # Battery and Current Power Supply Check
            $batteryInformation = (Get-WMIObject -Class "Win32_Battery")
            if ($batteryInformation.count -ne 0) {
                Write-Output "Battery Information" | Format-Table -Wrap
                Write-Output "-------------------------------------------------------"
                #Measure-BatteryCapacity        
                if (Get-BatteryState -like "*discharging*") {
                    do {
                        if ($batteryInformation.EstimatedChargeRemaining -ge "65") {
                            if ($batteryInformation.BatteryStatus -eq "2") {
                                $logger.informational("Battery is discharging but at acceptable level of charge. $($batteryInformation.EstimatedChargeRemaining)%")
                                Write-Host "Battery is discharging but at acceptable level of charge. $($batteryInformation.EstimatedChargeRemaining)%" -ForegroundColor Green

                                $logger.informational("The system has access to AC so no battery is being discharged.")
                                Write-output "The system has access to AC so no battery is being discharged."
                            }
                            else {
                                $logger.informational("Battery is discharging but at acceptable level of charge. $($batteryInformation.EstimatedChargeRemaining)% ")
                                Write-Host "Battery is discharging but at acceptable level of charge. $($batteryInformation.EstimatedChargeRemaining)% " -ForegroundColor Green
                            }
                        }
                        else {
                            $logger.Alert("Battery is currently at $($batteryInformation.EstimatedChargeRemaining)%, which is below the safety threshold, please plug in charger")
                            write-host "Battery is currently at $($batteryInformation.EstimatedChargeRemaining)%, which is below the safety threshold, please plug in charger" -ForegroundColor red | Format-Table -Wrap
                            [System.Media.SystemSounds]::Exclamation.Play()
                            Start-Sleep -Seconds 5
                        }

                    } until (($batteryInformation.EstimatedChargeRemaining -ge "65" -or $batteryInformation.BatteryStatus -eq "2" -or $batteryInformation.BatteryStatus -eq "3" -or $batteryInformation.BatteryStatus -eq "6"))
                }
                # Battery check if status is not "OK" and grabs FRU if bad
                if ($batteryInformation.Status -ne "OK") {
                    $logger.warning("Current battery may have operational issues, Status is '$($batteryInformation.Status)'")
                    Write-Host "Current battery may have operational issues, Status is '$($batteryInformation.Status))'" -ForegroundColor red
                    
                    $logger.warning("Battery FRU is $($batteryInformation.DeviceID), sometimes you need to omit the first couple of characters")
                    Write-Host "Battery FRU is $($batteryInformation.DeviceID), sometimes you need to omit the first couple of characters"

                    if ($batteryInformation.Availability) {
                        switch ($batteryInformation.Availability) {
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
                }
                else {
                    $logger.informational("Current battery should be operational, Status is '$($batteryInformation.Status)'")
                    Write-Host "Current battery should be operational, Status is '$($batteryInformation.Status)'" -ForegroundColor green
                }
            }
            else {
                $logger.warning("Current device is a $computerType, but there is no battery detected")                
                Write-Host "Current device is a $computerType, but there is no battery detected" -ForegroundColor red
            }
        }
    }
    
    end {
        # Windows OS/replace battery count Switch
        if ($replaceBattery -or $ForceReport) {
            switch -Wildcard ($replaceBatteryCount, $winProductName) {
                "1" {
                    $logger.warning("A New battery may be needed")
                    Write-Host "A New battery may be needed" -ForegroundColor Red ; continue
                }
                "2" {
                    $logger.warning("New battery(s) may be needed")
                    Write-Host "New battery(s) may be needed" -ForegroundColor Red ; continue
                }
                "*10*" { POWERCFG -batteryreport -output "$home\desktop\battery-report.html" ; break }
                "*7*" { POWERCFG -ENERGY -OUTPUT "$home\desktop\battery-report.html" ; break }
                default { "Unknown Operating System" }
            }
        }

        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
