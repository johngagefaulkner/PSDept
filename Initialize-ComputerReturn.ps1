<#
.SYNOPSIS
    Make a computer ready for storage
.DESCRIPTION
    Make a computer ready for storage
.EXAMPLE
    PS C:\> Initialize-ComputerReturn
    Checks the battery status/health, computer information, and BitLocker status. Decrypts the drive if bitlocked.
.INPUTS
    Inputs (if any)
.OUTPUTS
    Battery health status, machine info and if its decrypting the drive
.NOTES
    Version:        1.0
    Author:         Jon Cronce
    Creation Date:  05/24/2019
    Purpose/Change: Initial script development
#>
function Initialize-ComputerReturn {
    # Gets device type
    $CompConfig = Get-WmiObject -Class 'Win32_ComputerSystem' -computer $env:computername
    foreach ($ObjItem in $CompConfig) {
        $x = $ObjItem.PCSystemType
        $computerType = Switch ($x) {
            1 {"Desktop"; break}
            2 {"Mobile/Laptop"; break}
            3 {"Workstation"; break}
            4 {"Enterprise Server"; break}
            default {"Not a known Product Type"}
        }
    }
    function Measure-BatteryCapacity {
        [CmdletBinding()]
        param (
            [parameter(DontShow = $true)]
            $batteries = (Get-WmiObject -Class "BatteryStatus" -Namespace "ROOT\WMI"),

            [parameter(DontShow = $true)]
            $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName,

            [parameter(DontShow = $true)]
            $lowestAllowableBattCap = "68",

            [parameter(DontShow = $true)]
            $currentBattery = 0,

            [parameter(DontShow = $true)]
            $replaceBatteryCount = 0
        )
        
        begin {
            # Set Initial Battery Replacement Status 
            $ReplaceBattery = $false 
        }
        
        process {
            # If there is a battery,check each battery
            if ((Get-WmiObject -Class Win32_Battery).count -ne 0) {
                foreach ($battery in $batteries) {
                    $designedCapacity = (Get-WmiObject -Class "BatteryStaticData" -Namespace "ROOT\WMI").DesignedCapacity[$currentBattery]
                    $fullCharge = (Get-WmiObject -Class "BatteryFullChargedCapacity" -Namespace "ROOT\WMI").FullChargedCapacity[$currentBattery]
                    $batteryDeviceID = (Get-WmiObject -Class Win32_Battery).Name
                    $batteryDeviceID = $batteryDeviceID.split(" ")[$currentBattery]

                    # Make sure battery is not over 100%
                    $currentBatteryCapacity = ($FullCharge / $DesignedCapacity) * 100
                    if ($currentBatteryCapacity -gt 100) {
                        $currentBatteryCapacity = 100
                    }
                    # Round battery percentage
                    $currentBatteryCapacity = [decimal]::round($currentBatteryCapacity)

                    # Compare current capacity to lowest allowable
                    if ([int]$currentBatteryCapacity -le [int]$lowestAllowableBattCap) {
                        Write-Host "Battery[$CurrentBattery][Serial:$batteryDeviceID] capacity is at $($currentBatteryCapacity)%." -ForegroundColor Red
                        $replaceBatteryCount++
                        $replaceBattery = $true
                    }
                    
                    # Change current battery to next
                    $currentBattery++        
                }
            }
        }
        
        end {
            # Windows OS/replace battery count Switch
            if ($replaceBattery) {
                switch -Wildcard ($replaceBatteryCount, $winProductName) {
                    "1" {Write-Host "A New battery may be needed" -ForegroundColor Red ; continue}
                    "2" {Write-Host "New battery(s) may be needed" -ForegroundColor Red ; continue}
                    "*10*" {POWERCFG -batteryreport -output "$home\desktop\battery-report.html" ; break}
                    "*7*" {POWERCFG -ENERGY -OUTPUT "$home\desktop\battery-report.html" ; break}
                    default {"Unknown Operating System"}
                }
            }
        }
    }

    # Battery and Current Power Supply Check
    if ($computerType -eq "Mobile/Laptop") {
        if ((Get-WmiObject -Class Win32_Battery).count -ne 0) {
            Write-Output "Battery Information" | Format-Table -Wrap
            Write-Output "-------------------------------------------------------"
            Measure-BatteryCapacity
            # Create function to check battery status
            Function Confirm-BatteryState {
                param($Laptop = $env:computername)
                $batteryStatus = (Get-WmiObject -Class Win32_Battery -ea 0).BatteryStatus
                if ($batteryStatus) {
                    switch ($batteryStatus) {
                        1 {"Battery is discharging"; break}
                        2 {"The system has access to AC so no battery is being discharged. However, the battery is not necessarily charging."; break}
                        3 {"Fully Charged"; break}
                        4 {"Low"; break}
                        5 {"Critical"; break}
                        6 {"Charging"; break}
                        7 {"Charging and High"; break}
                        8 {"Charging and Low"; break}
                        9 {"Charging and Critical"; break}
                        10 {"Undefined"; break}
                        11 {"Partially Charged"; break}
                        default {"Not a known Status"}
                    }
                }
            }
            # If discharging check to see if its plugged in or certain power percentage, if not then loop til it happens
            if (Confirm-BatteryState -like "*discharging*") {
                do {
                    $batteryStatus = (Get-WmiObject -Class Win32_Battery -ea 0).BatteryStatus
                    $batteryPercentage = (Get-WmiObject -Class Win32_Battery).estimatedchargeremaining
                    if ($batteryPercentage -ge "65") {
                        if ($batteryStatus -eq "2") {
                            Write-Host "Battery is discharging but at acceptable level of charge. $batteryPercentage% " -ForegroundColor Green
                            Write-output "The system has access to AC so no battery is being discharged."
                        }
                        else {
                            Write-Host "Battery is discharging but at acceptable level of charge. $batteryPercentage% " -ForegroundColor Green
                        }
                    }
                    else {
                        write-host "Battery is currently at $batteryPercentage%, which is below the safety threshold, please plug in charger" -ForegroundColor red | Format-Table -Wrap
                        [System.Media.SystemSounds]::Exclamation.Play()
                        Start-Sleep -Seconds 5 #good
                    }

                } until (($batteryPercentage -ge "65" -or $batteryStatus -eq "2" -or $batteryStatus -eq "3" -or $batteryStatus -eq "6"))#good
            }
            # Battery check if status is not "OK" and grabs FRU if bad
            $bStatus = (Get-WmiObject -Class Win32_Battery).Status
            $batteryAvailability = (Get-WmiObject -Class Win32_Battery).Availability
            $batteryDeviceID = (Get-WmiObject -Class Win32_Battery).DeviceID
            if ($bStatus -ne "OK") {
                Write-Host "Current battery may have operational issues, Status is '$bStatus'" -ForegroundColor red
                Write-Host "Battery FRU is $batteryDeviceID, sometimes you need to omit the first couple of characters"
                if ($batteryAvailability) {
                    switch ($batteryAvailability) {
                        1 {"Other"; break}
                        2 {"Unknown - Most likely on AC"; break}
                        3 {"Running or Full Power"; break}
                        4 {"Warning"; break}
                        10 {"Degraded"; break}
                        12 {"Install Error"; break}
                        17 {"Power Save - Warning"; break}
                        default {"Not a known Battery Availability"}
                    }
                }
            }
            else {
                Write-Host "Current battery should be operational, Status is '$bStatus'" -ForegroundColor green
            }
        }
        else {
            Write-Host "Current device is a $computerType, but there is no battery detected" -ForegroundColor red
        }
    }

    # Checks the bitlocker status
    $driveToBitlock = Get-BitLockerVolume -MountPoint "C:"
    if ($driveToBitlock.VolumeStatus -eq "FullyDecrypted") {
        Write-Host "BitLocker Status:" -NoNewLine
        Write-Host " $($driveToBitlock.VolumeStatus)" -ForegroundColor Red -BackgroundColor Black
    }
    ELSE {
        Write-Host "BitLocker Status:" -NoNewLine
        Write-Host " $($driveToBitlock.VolumeStatus)" -ForegroundColor Green
        Write-Verbose -Message "Disabling Bitlocker..." -Verbose
        Disable-BitLocker -MountPoint "C:"
        fvenotify.exe
    }    
    
    function Get-MachineInformation {
        [CmdletBinding()]
        param (
            $computerSystem = (Get-CimInstance -ClassName 'Win32_ComputerSystem' -property Manufacturer,Model,TotalPhysicalMemory,UserName),
            $computerBIOS = (Get-CimInstance -ClassName 'Win32_BIOS' -property SerialNumber),
            $computerOS = (Get-CimInstance -ClassName 'Win32_OperatingSystem' -property caption ),
            $computerCPU = (Get-CimInstance -ClassName 'Win32_Processor' -property Name,numberofcores ),
            $computerHDD = (Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DeviceId = "C:"'),
            $computerMacAddress = (Get-CimInstance win32_networkadapterconfiguration -property Description,MACAddress | 
                Where-Object {($null -ne $_.macaddress) -and ($_.Description -like "*Wireless*" -or $_.Description -like "*Ethernet*" -or $_.Description -like "*ac*")}),
            $upTime = ([timespan]::FromMilliseconds([Math]::Abs([Environment]::TickCount))),
            $winVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId      
        )
        if (($computerMacAddress.Description).count -le 1){
            $ethernet = "$($computerMacAddress.Description): [$($computerMacAddress.MACAddress -replace ":", "-")]" 
            $wifi = "$($computerMacAddress.Description): [$($computerMacAddress.MACAddress -replace ":", "-")]"
        }else{
            $ethernet = "$($computerMacAddress.Description[0]): [$($computerMacAddress.MACAddress[0]-replace ":", "-")]" 
            $wifi = "$($computerMacAddress.Description[1]): [$($computerMacAddress.MACAddress[1]-replace ":", "-")]"
        }

        Write-host "System Information for: " $computerSystem.Name -BackgroundColor DarkCyan
        "-------------------------------------------------------"
        [PSCUSTOMOBJECT]@{
            Manufacturer  = $computerSystem.Manufacturer
            Model         = $computerSystem.Model
            SerialNumber  = $computerBIOS.SerialNumber
            CPU           = $($computerCPU.Name)
            Cores         = $($computerCPU.numberofcores)
            DriveCapacity = "$([Math]::Round(($computerHDD.Size/1GB)))GB"
            RAM           = "$([Math]::Round(($computerSystem.TotalPhysicalMemory/1GB)))GB"
            OS            = "$($computerOS.caption) $winVersion"
            Ethernet      = $ethernet 
            WiFi          = $wifi
            CurrentUser   = $computerSystem.UserName
            Uptime        = "Days:$($upTime.Days) Hours:$($upTime.hours) Minutes:$($upTime.Minutes)"
        }
        "-------------------------------------------------------"
    }
    Get-MachineInformation
    Pause
}
Initialize-ComputerReturn