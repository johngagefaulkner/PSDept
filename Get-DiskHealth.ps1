function Get-DiskHealth {
    <#
    .SYNOPSIS
        Obtain the selected disks health and wear levels.

    .DESCRIPTION
        Check the disks avaiable information on its abilities and current wear levels or power on hours.

    .PARAMETER Drive
        The drive you wish to check.

    .PARAMETER Report
        Switch to enable an object report of the disk and its information.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Example of how to run the script.

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        $Drive = (Get-Disk | Where-Object { ($_.isboot -Eq "true" -and $_.Bustype -ne "USB") } | Select-Object *),

        [parameter(Mandatory = $false)]
        [switch]$Report,

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
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        try {
            $SMART = (Get-CimInstance -namespace root\wmi -ClassName "MSStorageDriver_FailurePredictStatus" -ea stop)
        }
        catch [Microsoft.Management.Infrastructure.CimException] {
            Write-Error -message "This storage drive model doesn't support S.M.A.R.T or is not enabled in BIOS/UEFI"
            $logger.Error("This storage drive model doesn't support S.M.A.R.T or is not enabled in BIOS/UEFI")
        }
        catch{
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

        function Format-HumanReadableByteSize {
            param (
                [parameter(ValueFromPipeline)]
                [ValidateNotNullorEmpty()]
                [double]$InputObject
            )

            # Handle this before we get NaN from trying to compute the logarithm of zero
            if ($InputObject -eq 0) {
                return "0 Bytes"
            }
            
            $magnitude = [math]::truncate([math]::log($InputObject, 1024))
            $normalized = $InputObject / [math]::pow(1024, $magnitude)
            
            $magnitudeName = switch ($magnitude) {
                0 { "Bytes"; Break }
                1 { "KB"; Break }
                2 { "MB"; Break }
                3 { "GB"; Break }
                4 { "TB"; Break }
                5 { "PB"; Break }
                Default { Throw "Byte value too big" }
            }
            
            "{0:n2} {1}" -f ($normalized, $magnitudeName)
        }   
        
        Function Get-SMARTAttributes {
   
            [CmdletBinding(DefaultParameterSetName = "Index",
                PositionalBinding = $True,
                HelpUri = "https://github.com/BoonMeister/Get-SMARTAttributes")]
            [OutputType("System.Management.Automation.PSCustomObject")]
            Param(
                [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Index", Position = 0)]
                [Alias("Index", "Number", "DiskNumber")]
                [uint32]$DiskIndex,
                [Parameter(Mandatory = $True, ParameterSetName = "Serial")]
                [Alias("Serial Number", "Serial")]
                [string]$SerialNumber,
                [Parameter(Mandatory = $True, ParameterSetName = "Caption")]
                [Alias("Model", "Friendly Name")]
                [string]$Caption,
                [Parameter(Mandatory = $False)]
                [switch]$Show = $False,
                [Parameter(Mandatory = $False)]
                [switch]$NoWarning = $False
            )
            Begin {
                $Error.Clear()
                $RealValueArray = @(3, 4, 5, 9, 10, 12, 171, 172, 173, 174, 176, 177, 179, 180, 181, 182, 183, 184, 187, 188, 189, 190, 193, 194, 196, 197, 198, 199, 235, 240, 241, 242, 243)
                $AttIDToName = @{
                    1   = 'RawReadErrorRate'
                    2   = 'ThroughputPerformance'
                    3   = 'SpinUpTime'
                    4   = 'StartStopCount'
                    5   = 'ReallocatedSectorCount'
                    6   = 'ReadChannelMargin'
                    7   = 'SeekErrorRate'
                    8   = 'SeekTimePerformance'
                    9   = 'PowerOnHoursCount'
                    10  = 'SpinRetryCount'
                    11  = 'CalibrationRetryCount'
                    12  = 'PowerCycleCount'
                    170 = 'AvailableReservedSpace'
                    171 = 'ProgramFailCount'
                    172 = 'EraseFailCount'
                    173 = 'WearLevelingCount'
                    174 = 'UnexpectedPowerLoss'
                    175 = 'PowerLossProtectionFailure'
                    176 = 'EraseFailCount(Chip)'
                    177 = 'WearRangeDelta'
                    179 = 'UsedReservedBlockCountTotal'
                    180 = 'UnusedReservedBlockCountTotal'
                    181 = 'ProgramFailCountTotal'
                    182 = 'EraseFailCount'
                    183 = 'RuntimeBadBlockTotal'
                    184 = 'EndToEndError'
                    185 = 'HeadStability'
                    186 = 'InducedOpVibrationDetection'
                    187 = 'UncorrectableErrorCount'
                    188 = 'CommandTimeout'
                    189 = 'HighFlyWrites'
                    190 = 'AirflowTemperature'
                    191 = 'G-senseErrorRate'
                    192 = 'PoweroffRetractCount'
                    193 = 'LoadCycleCount'
                    194 = 'Temperature'
                    195 = 'HardwareECCRecovered'
                    196 = 'ReallocationEventCount'
                    197 = 'CurrentPendingSectorCount'
                    198 = 'OfflineUncorrectableSectorCount'
                    199 = 'UltraDMACRCErrorCount'
                    200 = 'Multi-ZoneErrorRate'
                    201 = 'SoftReadErrorRate'
                    202 = 'DataAddressMarkErrors'
                    203 = 'RunOutCancel'
                    204 = 'SoftECCCorrection'
                    205 = 'ThermalAsperityRate'
                    206 = 'FlyingHeight'
                    207 = 'SpinHighCurrent'
                    208 = 'SpinBuzz'
                    209 = 'OfflineSeekPerformance'
                    210 = 'VibrationDuringWrite'
                    211 = 'VibrationDuringWrite'
                    212 = 'ShockDuringWrite'
                    220 = 'DiskShift'
                    221 = 'G-SenseErrorRate'
                    222 = 'LoadedHours'
                    223 = 'Load/UnloadRetryCount'
                    224 = 'LoadFriction'
                    225 = 'Load/UnloadCycleCount'
                    226 = 'LoadInTime'
                    227 = 'TorqueAmplificationCount'
                    228 = 'Power-OffRetractCycle'
                    230 = 'GMRHeadAmplitude/DriveLifeProtectionStatus'
                    231 = 'LifeLeft'
                    232 = 'EnduranceRemaining/AvailableReservedSpace'
                    233 = 'MediaWearoutIndicator'
                    234 = 'Average/MaximumEraseCount'
                    235 = 'Good/FreeBlockCount'
                    240 = 'HeadFlyingHours'
                    241 = 'TotalLBAsWritten'
                    242 = 'TotalLBAsRead'
                    243 = 'TotalLBAsWrittenExpanded'
                    244 = 'TotalLBAsReadExpanded'
                    249 = 'NANDWrites'
                    250 = 'ReadErrorRetryRate'
                    251 = 'MinimumSparesRemaining'
                    252 = 'NewlyAddedBadFlashBlock'
                    254 = 'FreeFallProtection'
                }
            }
            Process {
                # Determine disk
                switch ($PSBoundParameters) {
                    ( { $PSBoundParameters.ContainsKey("SerialNumber") }) {
                        $FilterQuery = "Index = '$DiskIndex'" ; Break
                    }
                    ( { $PSBoundParameters.ContainsKey("SerialNumber") }) {
                        $FilterQuery = "SerialNumber = '$SerialNumber'" ; Break
                    }
                    Default { $FilterQuery = "Index = '$DiskIndex'" }
                }
               
                Try { 
                    $SelectedDisk = Get-WmiObject -Class Win32_DiskDrive -Filter $FilterQuery -ErrorAction Stop 
                }
                Catch { 
                    Throw "An unexpected exception has occurred querying WMI for disk info"
                    $logger.error("An unexpected exception has occurred querying WMI for disk info") 
                }
                If (($SelectedDisk | Measure-Object).Count -eq 0) { 
                    Throw "No disk was found that matched the filter query '$FilterQuery'"
                    $logger.error("No disk was found that matched the filter query '$FilterQuery'") 
                }
                ElseIf (($SelectedDisk | Measure-Object).Count -gt 1) {
                    Throw "More than one disk was found that matched the filter query '$FilterQuery'"
                    $logger.error("More than one disk was found that matched the filter query '$FilterQuery'") 
                }
                Else {
                    # Get SMART & threshold data
                    Try {
                        $SMARTAttributeData = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_ATAPISmartData -ErrorAction Stop | Where-Object { $_.InstanceName -like "*$($SelectedDisk.PNPDeviceID)*" }
                        $ThresholdData = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictThresholds -ErrorAction Stop | Where-Object { $_.InstanceName -like "*$($SelectedDisk.PNPDeviceID)*" }
                    }
                    Catch [System.Management.ManagementException] { 
                        Throw "Access was denied when querying SMART data - Please ensure you are running as Admin or with the necessary privileges"
                        $logger.error("Access was denied when querying SMART data - Please ensure you are running as Admin or with the necessary privileges") 
                    }
                    Catch { 
                        Throw "An unexpected exception has occurred querying SMART and threshold data for [$($SelectedDisk.Caption)]"
                        $logger.error("An unexpected exception has occurred querying SMART and threshold data for [$($SelectedDisk.Caption)]") 
                    }
                }
                If (($SMARTAttributeData | Measure-Object).Count -eq 0 -and !$NoWarning) { 
                    Write-Warning -Message "Could not retrieve SMART data for the disk [$($SelectedDisk.Caption)]. Please ensure the disk is capable and SMART is enabled" 
                    $logger.warning("Could not retrieve SMART data for the disk [$($SelectedDisk.Caption)]. Please ensure the disk is capable and SMART is enabled")
                }
                ElseIf (($SMARTAttributeData | Measure-Object).Count -eq 1) {
                    # Select threshold data and determine loop count
                    $AttributeThresholds = ($ThresholdData.VendorSpecific)[2..($ThresholdData.VendorSpecific.Count - 1)]
                    $ThresholdLoopCount = [System.Math]::Floor($AttributeThresholds.Count / 12)
                    # Create hash table of attribute IDs to threshold values
                    $AttIDToThreshold = @{ }
                    For ($ThreshIterate = 0; $ThreshIterate -lt $ThresholdLoopCount; $ThreshIterate++) {
                        If ($AttributeThresholds[($ThreshIterate * 12)] -ne 0) {
                            $AttIDToThreshold.Add($AttributeThresholds[($ThreshIterate * 12)], $AttributeThresholds[($ThreshIterate * 12 + 1)])
                        }
                    }
                    # Select SMART data and determine loop count
                    $VendorSpecData = $SMARTAttributeData.VendorSpecific
                    $AttLoopCount = [System.Math]::Floor($VendorSpecData.Count / 12)
        
                    # Loop through spec data array in chunks of 12
                    $StartIndex, $EndIndex = 1, 12
                    $ResultArray = @()
                    For ($AttIterate = 0; $AttIterate -lt $AttLoopCount; $AttIterate++) {
                        $CurrentAtt = $VendorSpecData[$StartIndex..$EndIndex]
        
                        If ([int]$CurrentAtt[1] -ne 0) {
                            # Construct data
                            $RawValue = [System.BitConverter]::ToString([byte[]]($CurrentAtt[11], $CurrentAtt[10], $CurrentAtt[9], $CurrentAtt[8], $CurrentAtt[7], $CurrentAtt[6])) -replace "-"
                            $AttributeIDHex = "0x" + [System.BitConverter]::ToString([byte]$CurrentAtt[1])
                            $ThresholdValue = $AttIDToThreshold.([byte]$CurrentAtt[1])
                            
                            If ($CurrentAtt[4] -ge $ThresholdValue) {
                                $ThresholdStatus = "OK" 
                            }
                            Else {
                                $ThresholdStatus = "FAIL" 
                            }
        
                            If ($AttIDToName.ContainsKey([int]$CurrentAtt[1])) { 
                                $AttributeName = $AttIDToName.([int]$CurrentAtt[1]) 
                            }
                            Else { 
                                $AttributeName = "VendorSpecific/Unknown" 
                            }
        
                            # Real values
                            If ($RealValueArray -contains [int]$CurrentAtt[1]) {
                                If (9, 240 -contains [int]$CurrentAtt[1]) { 
                                    $RawInt = [System.Convert]::ToInt64($RawValue.Substring(4), 16) 
                                }
                                Else { 
                                    $RawInt = [System.Convert]::ToInt64($RawValue, 16) 
                                }
        
                                Switch ([int]$CurrentAtt[1]) {
                                    3 {
                                        # Spin up time
                                        $RealValue = $RawInt.ToString('N0') + " ms"
                                        Break
                                    }
                                    9 {
                                        # Power on hours
                                        $TimeSpan = [timespan]::FromDays($RawInt / 24)
                                        $RealValue = "$($TimeSpan.Days)d $($TimeSpan.Hours)h"
                                        Break
                                    }
                                    190 {
                                        # Airflow temperature
                                        $RealValue = "$($CurrentAtt[6])C"
                                        If (($CurrentAtt[8] -gt 0) -and ($CurrentAtt[9] -gt 0)) { $RealValue += " (Min=$($CurrentAtt[8]),Max=$($CurrentAtt[9]))" }
                                        Break
                                    }
                                    194 {
                                        # Temperature
                                        $RealValue = "$($CurrentAtt[6])C"
                                        If (($CurrentAtt[7] -gt 0) -and ($CurrentAtt[8] -gt 0)) { $RealValue += " (Min=$($CurrentAtt[7]),Max=$($CurrentAtt[8]))" }
                                        Break
                                    }
                                    240 {
                                        # Head flying hours
                                        $TimeSpan = [timespan]::FromDays($RawInt / 24)
                                        $RealValue = "$($TimeSpan.Days)d $($TimeSpan.Hours)h"
                                        Break
                                    }
                                    Default {
                                        $RealValue = $RawInt.ToString('N0')
                                        Break
                                    }
                                }
                            }
                            Else { 
                                $RealValue = "0" 
                            }
        
                            if ($AttributeIDHex -like "0xF1") {
                                $RealValue = $RealValue -replace (',', '')
                                $RealValue = ([double]$RealValue * 512)
                                $script:TotalLBAsWritten = @(
                                    @{AttName = "TotalLBAsWritten" ; RealValue = $RealValue }
                                )
                            }
                            # Create object and add to final array
                            $AttributeObj = [PSCustomObject]@{
                                AttID     = "$AttributeIDHex"
                                AttName   = $AttributeName
                                RealValue = $RealValue
                                Current   = "$($CurrentAtt[4])"
                                Worst     = "$($CurrentAtt[5])"
                                Threshold = "$($ThresholdValue)"
                                Status    = $ThresholdStatus
                                RawValue  = $RawValue
                            }
                            $ResultArray += $AttributeObj
                        }
                        $StartIndex += 12
                        $EndIndex += 12
                    }
                    if ($Show) {
                        $ResultArray
                    }
                }
            }
        }

        try {
            $diskHealth = $Drive | Get-PhysicalDisk | Get-StorageReliabilityCounter
            
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    process {
        try {
            if ($null -ne $SMART) {
                foreach ($FailurePredictStatus in $SMART) {
                    if ($FailurePredictStatus.predictfailure) {
                        Write-host "S.M.A.R.T is predicting a hard drive failure. Check drive." -ForegroundColor RED
                        $logger.warning("S.M.A.R.T is predicting a hard drive failure. Check drive.")
                        [PSCustomObject]@{
                            InstanceName   = $FailurePredictStatus.InstanceName
                            PredictFailure = $FailurePredictStatus.PredictFailure
                            ReasonCode     = $FailurePredictStatus.Reason
                        }
                    }
                }
            }
            switch ($diskAttributes) {
                ( { $diskHealth.wear -gt 70 }) {
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Wear level is ($($diskhealth.wear)/100). Consider replacing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Wear level is ($($diskhealth.wear)/100). Consider replacing drive.")
                }
                ( { $diskHealth.ReadErrorsUncorrected -gt 0 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Read Errors Uncorrected are at $($diskHealth.ReadErrorsUncorrected). Consider testing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Read Errors Uncorrected are at $($diskHealth.ReadErrorsUncorrected). Consider testing drive.")
                }
                ( { $diskHealth.WriteErrorsUncorrected -gt 0 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Write Errors Uncorrected are at $($diskHealth.WriteErrorsUncorrected). Consider testing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Write Errors Uncorrected are at $($diskHealth.WriteErrorsUncorrected). Consider testing drive.")
                }
                ( { $diskHealth.FlushLatencyMax -gt 10000 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Flush Latency Max is $($diskhealth.FlushLatencyMax). Consider testing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Flush Latency Max is $($diskhealth.FlushLatencyMax). Consider testing drive.")
                }
                ( { $diskHealth.ReadLatencyMax -gt 10000 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Read Latency Max is $($diskhealth.ReadLatencyMax). Consider testing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Read Latency Max is $($diskhealth.ReadLatencyMax). Consider testing drive.")
                }
                ( { $diskHealth.WriteLatencyMax -gt 10000 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Write Latency ax is $($diskhealth.WriteLatencyMax). Consider testing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Write Latency ax is $($diskhealth.WriteLatencyMax). Consider testing drive.")
                }
                ( { ($TotalLBAsWritten.realvalue) -gt 109951162777600 }) { 
                    Write-Warning -Message "Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Data written to drive, [$($TotalLBAsWritten.realvalue | Format-HumanReadableByteSize)], has exceeded 100TB. Consider replacing drive."
                    $Report = $true
                    $logger.Critical("Serial: [$($Drive.SerialNumber)] $($Drive.FriendlyName) Data written to drive, [$($TotalLBAsWritten.realvalue | Format-HumanReadableByteSize)], has exceeded 100TB. Consider replacing drive.")
                }
                Default { 
                    Write-Output "Disk wear and latency levels are in good health" 
                    $logger.informational("Disk wear and latency levels are in good health" )
                }
            }
            if (($Report) -and ($null -ne $SMART)) {
                $drive | Get-SMARTAttributes -Show | format-table
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        try {
            if ($Report) {            
                [PSCustomObject]@{
                    PowerOnHours           = if ($null -eq $diskHealth.PowerOnHours) { "N/A" } else { $diskHealth.PowerOnHours }
                    ReadErrorsCorrected    = if ($null -eq $diskHealth.ReadErrorsCorrected) { "N/A" } else { $diskHealth.ReadErrorsCorrected }
                    ReadErrorsTotal        = if ($null -eq $diskHealth.ReadErrorsTotal) { "N/A" } else { $diskHealth.ReadErrorsTotal }
                    ReadErrorsUncorrected  = if ($null -eq $diskHealth.ReadErrorsUncorrected) { "N/A" } else { $diskHealth.ReadErrorsUncorrected }
                    Wear                   = if ($null -eq $diskHealth.Wear) { "N/A" } else { $diskHealth.Wear }
                    WriteErrorsCorrected   = if ($null -eq $diskHealth.WriteErrorsCorrected) { "N/A" } else { $diskHealth.WriteErrorsCorrected }
                    WriteErrorsTotal       = if ($null -eq $diskHealth.WriteErrorsTotal) { "N/A" } else { $diskHealth.WriteErrorsTotal }
                    WriteErrorsUncorrected = if ($null -eq $diskHealth.WriteErrorsUncorrected) { "N/A" } else { $diskHealth.WriteErrorsUncorrected }
                    FlushLatencyMax        = if ($null -eq $diskHealth.FlushLatencyMax) { "N/A" } else { $diskHealth.FlushLatencyMax }
                    ReadLatencyMax         = if ($null -eq $diskHealth.ReadLatencyMax) { "N/A" } else { $diskHealth.ReadLatencyMax }
                    WriteLatencyMax        = if ($null -eq $diskHealth.WriteLatencyMax) { "N/A" } else { $diskHealth.WriteLatencyMax }
                    SerialNumber           = if ($null -eq $Drive.SerialNumber) { "N/A" } else { $Drive.SerialNumber }
                    FriendlyName           = if ($null -eq $Drive.FriendlyName) { "N/A" } else { $Drive.FriendlyName }
                    ClassInfo              = "https://docs.microsoft.com/en-us/previous-versions/windows/desktop/stormgmt/msft-storagereliabilitycounter"
                }
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
}
