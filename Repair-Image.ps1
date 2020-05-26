function Repair-Image {
    <#
    .SYNOPSIS
        Repairs an image

    .DESCRIPTION
        This script will validate the path given for a local repair source and make sure it exists, type, and extension meets requirements first.
        Then it will test to see if the CSB log file is locked, if it is then it will unlock it. Once unlocked, if it hasn't refreshed in 
        the last 5 minutes then it will delete the current CBS log and refresh it.
        When it has completed it will then parse the log file to see what has been fixed and show the results on the screen.

        It will then test and fix the ReagentC xml file and resolve component store items.
        A Online health check will then kick off to check for corruption, if it passes the script finishes. If it fails, it continues on to check the internet connection. 
        If below 5% packet loss then it will pull an image from Microsoft to fix component store corruption and log it to "C:\RestoreHealth.log".
        If the internet connection is bad then it can use a network stored image or locally stored image path. It will mount, index, and convert
        the image and try to repair windows using it. Logs will go to "C:\RepairLogs"

    .PARAMETER LocalImage
        Give a path for a ISO,WIM,ESD on a USB drive or drive local to the computer

    .PARAMETER ShareImage
        Give a path for a ISO,WIM,ESD such as on a USB drive or drive local to the computer
    
    .PARAMETER AcceptableRate
        The allowable percentage of packets dropped

    .PARAMETER CBSPath
        Where the cbspath is being logged

    .PARAMETER CBSLifeSpan
        How long the since the file was last created before needing to be deleted.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .PARAMETER UseSource
       Switch that enables or disables the needed use of ISO,WIM,ESD files instead of online fix.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Repair-Image -LocalImage "$home\desktop\win10.iso"

    .EXAMPLE
        Repair-Image -ShareImage "\\server\path\install.wim"

    .EXAMPLE
        Repair-Image -AcceptableRate 75

    .EXAMPLE
        Repair-Image -CBSLifeSpan -10

    .EXAMPLE
        Repair-Image -UseSource

    .EXAMPLE
        Repair-Image -LocalImage "$home\desktop\win10.iso" -ShareImage "\\server\path\install.wim" -AcceptableRate 75 -CBSLifeSpan -10 -UseSource

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
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "File does not exist"
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw "The Path argument must be a file. Folder paths are not allowed."
                }
                if ($_ -notmatch "(\.wim|\.esd|\.iso)") {
                    throw "The file specified in the path argument must be either of type wim, esd, or iso"
                }
                return $true 
            })]
        [System.IO.FileInfo]$LocalImage,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "File does not exist"
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw "The Path argument must be a file. Folder paths are not allowed."
                }
                if ($_ -notmatch "(\.wim|\.esd|\.iso)") {
                    throw "The file specified in the path argument must be either of type wim, esd, or iso"
                }
                return $true 
            })]
        [System.IO.FileInfo]$ShareImage = "\\Server\Path\Here\sources\install.wim",

        [Parameter(Mandatory = $false)]
        [ValidateRange(70, 95)]
        [int]$AcceptableRate = "95.00",

        [Parameter(Mandatory = $false)]
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "File does not exist"
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw "The Path argument must be a file. Folder paths are not allowed."
                }
                if ($_ -notmatch "(\.wim|\.esd|\.iso)") {
                    throw "The file specified in the path argument must be either of type wim, esd, or iso"
                }
                return $true 
            })]
        [System.IO.FileInfo]$CBSPath = "$env:SystemRoot\Logs\CBS\CBS.log",

        [Parameter(Mandatory=$false)]
        [ValidateRange(0,9999)]
        [int]$CBSLifeSpan = -5,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp",

        [Parameter(Mandatory = $false)]
        [switch]$UseSource
    )
    
    begin {

        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath, $callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

        $scriptTimer = [Diagnostics.Stopwatch]::StartNew()
        #[int]$timeout = 0

        $logLevel = @{
            LogLevel = "WarningsInfo"
            LogPath  = "$logPath\RestoreHealth.log"
        }

        # Sources for the repair image paths
        $imageSources = @(
            "$LocalImage",
            "$ShareImage"
        )

        # CBS keywords
        $restoreKeywords = @(
            "Total Detected",
            "Manifest Corruption",
            "Metadata Corruption",
            "Payload Corruption",
            "Total Repaired",
            "Manifest Repaired",
            "Payload Repaired",
            "Total Operation"
        )

        function Compare-SFCOuput {
            [CmdletBinding()]
            param (
           
            )
       
            begin {
                
                # Output of successful repairs or checks
                $virtue = @(
                    "f.o.u.n.d...c.o.r.r.u.p.t...f.i.l.e.s...a.n.d...s.u.c.c.e.s.s.f.u.l.l.y...r.e.p.a.i.r.e.d...t.h.e.m.",
                    "d.i.d...n.o.t...f.i.n.d...a.n.y...i.n.t.e.g.r.i.t.y...v.i.o.l.a.t.i.o.n.s.",
                    "T.h.e...c.o.m.p.o.n.e.n.t...s.t.o.r.e...i.s...r.e.p.a.i.r.a.b.l.e"
                )

                # Image may need to be offline to be repaired
                $limbo = @(
                    "c.o.u.l.d...n.o.t...p.e.r.f.o.r.m...t.h.e...r.e.q.u.e.s.t.e.d...o.p.e.r.a.t.i.o.n."
                )

                # Image could not be repaired
                $nefarious = @(
                    "c.o.r.r.u.p.t...f.i.l.e.s...b.u.t...w.a.s...u.n.a.b.l.e...t.o...f.i.x...s.o.m.e...o.f...t.h.e.m.",
                    "T.h.e...s.o.u.r.c.e...f.i.l.e.s...c.o.u.l.d...n.o.t...b.e...f.o.u.n.d."
                )

                $SFCResponses = @(
                    @{Name = "virtue" ; Response = $virtue ; Bool = $False },
                    @{Name = "limbo" ; Response = $limbo ; Bool = $False },
                    @{Name = "nefarious" ; Response = $nefarious ; Bool = $False }
                )
            }
       
            Process {
                $imageSFC = C:\WINDOWS\system32\sfc.exe /scannow
                foreach ($SFCResponse in $SFCResponses) {
                    $exist = $imageSFC | Select-String -Pattern $SFCResponse.Response
                    $SFCResponse.Bool = [bool]($null -ne $exist)
                    $SFCResponse.Description = $exist -replace "\s{1}\b", ""
                }
            }
       
            end {
                return $SFCResponses
                
            }
        }

        Function Test-IsFileLocked {
            [cmdletbinding()]
            Param (
                [parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
                [Alias('FullName', 'PSPath')]
                [string[]]$Path = $cbsPath
            )
            Process {
                ForEach ($Item in $Path) {
                    # Ensure this is a full path
                    $Item = Convert-Path $Item
                    # Verify that this is a file and not a directory
                    If ([System.IO.File]::Exists($Item)) {
                        Try {
                            $FileStream = [System.IO.File]::Open($Item, 'Open', 'Write')
                            $FileStream.Close()
                            $FileStream.Dispose()
                            $IsLocked = $False
                            return $False
                        }
                        Catch [System.UnauthorizedAccessException] {
                            $IsLocked = 'AccessDenied'
                        }
                        Catch {
                            $IsLocked = $True
                            return $True
                        }
                        [pscustomobject]@{
                            File     = $Item
                            IsLocked = $IsLocked
                        }
                    }
                }
            }
        }
        
        #Add dism log parsing
        #C:\Windows\Logs\DISM
        function Show-DISMResults {
            param (
                $setting = ""
            )
            Write-Warning -Message "Scanning DISM Log File.."
        }
        
        function Show-CBSResults {
            
            $logger.informational("Scanning CBS Log File..")
            Write-Warning -Message "Scanning CBS Log File.."
            # Scan Array
            $scans = @(
                @{boolean = "\[SR\]" ; date = "[SR]" ; keyword = "[SR]" },
                @{boolean = "Manifest Corruption" ; date = "Manifest Corruption" ; keyword = $restoreKeywords }
            )
            foreach ($scan in $scans) {
                # Reuse Variable to grab cbs content
                $csbPath = Get-Content "$cbsPath"
                # Checks to see if a scan was run at all for the item
                $ScanBoolean = if ($csbPath | Where-Object { $_ -match "$($scan.Boolean)" } | 
                    Select-Object -first 1) { "TRUE" } else { "FALSE" }

                if ($ScanBoolean -eq $True) {
                    # Outputs the restore scan lines with last checkdate
                    $dateScan = $csbPath | Where-Object { $_.Contains("$($scan.date)") } | 
                    Select-object -Property @{Name = "LastCheckDate"; Expression = { $_.substring(0, 10) } } -last 1
    
                    # Filter out the known good lines and get only the interesting lines
                    foreach ($keyword in $($scan.keyword)) {
                        $csbPath | where-object { $_.Contains("$keyword") -and $_.Contains($dateScan.lastcheckdate) } | 
                        Select-String -notmatch "Verify complete", "Verifying", "Beginning Verify and Repair" #*>&1
                    }
                }
            }
            "---------------------------------------"
            
        }

        function Test-Internet {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $False)]
                $hosts = "www.google.com",
                [parameter(DontShow = $true)]
                $count = $Hosts.count,
                [parameter(DontShow = $true)]
                $i = 0,
                [parameter(DontShow = $true)]
                $Success = (New-Object int[] $Count),
                [parameter(DontShow = $true)]
                $Total = (New-Object int[] $Count)
            )
            
            $logger.informational("Checking Internet Connection Rate")
            Write-Warning "Checking Internet Connection Rate"
            $Hosts | ForEach-Object {
                $total[$i]++
                if (test-connection -ComputerName "$Hosts" -Count 10 -ErrorAction SilentlyContinue) {
                    $success[$i] += 1
                    # Percent calculated on basis of number of attempts made
                    [int]$successPercent = $("{0:N2}" -f (($success[$i] / $total[$i]) * 100))
                }
            }
            Return $successPercent
            
        }

        function Resolve-ReagentC {
            param(
                $partitions = (Get-Partition -DiskNumber 0 | Where-Object {$_.type -match "Recovery"})
            )
            begin {
                $ErrorActionPreference = "SilentlyContinue"
                $logger.warning("Checking Windows Recovery Environment...")
                Write-Warning -Message "Checking Windows Recovery Environment..."
        
                $env:SystemDirectory = [Environment]::SystemDirectory
                $xml = "$env:SystemDirectory\Recovery\ReAgent.xml"
                $analyzeReagentc = Invoke-Expression "$env:SystemDirectory\ReagentC.exe /info"   
                $analyzeReagentcEnabled = "$AnalyzeReagentC" -Match [regex]::new("Enabled")
                $analyzeReagentcDisabled = "$AnalyzeReagentC" -Match [regex]::new("Disabled")
            }
            process {
                if ($analyzeReagentcEnabled) {
                    $logger.informational("Windows RE Status: Enabled")
                    Write-Host "Windows RE Status: Enabled" -ForegroundColor Green
                }
                elseif ($analyzeReagentcDisabled) {
                    try {
                        Write-Verbose -Message "Enabling Windows Recovery Environment" -Verbose
                        if (test-path -Path $xml) {
                            $logger.warning("Removing $xml")
                            Remove-Item -Path $xml
                        }
                        $enableWinRE = Invoke-Expression "$env:SystemDirectory\ReagentC.exe /enable" 
                    }
                    catch {
                        $logger.Error("$PSitem")
                        $PSCmdlet.ThrowTerminatingError($PSitem)
                    }
                }
                else {
                    $logger.warning("Unknown Windows RE Status")
                    Write-Host "Unknown Windows RE Status" -ForegroundColor Yellow
                }
        
                try {
                    if ($partitions.count -gt 1) {
                        [string]$recoveryPartition = $analyzeReagentc | select-string -pattern "partition"
                        if(!([string]::IsNullOrWhiteSpace($recoveryPartition))){
                            if($recoveryPartition -match '(partition+\d)') {
                                $logger.informational("$($matches[0]) is the current recovery partition, removing non-used recovery partition")
                                Write-output "$($matches[0]) is the current recovery partition, removing non-used recovery partition"
                                if($matches[0] -match'(\d)') {
                                    $partitions | Where-Object {$_.PartitionNumber -notcontains "$($matches[0])"} | Remove-Partition
                                    $logger.informational("Removed non-used recovery partition")
                                }
                            }                
                        }                
                    }
                }
                catch {
                    $logger.Error("$PSitem")
                    $PSCmdlet.ThrowTerminatingError($PSitem)
                }
        
            }
            end {
                
                "---------------------------------------"
            }
        }      
        Resolve-ReagentC
        
      
        
        function Resolve-ComponentStore {
            
            $logger.informational("Analyzing Windows Component Store")
            Write-Warning -message "Analyzing Windows Component Store"
            $AnalyzeComponentStore = Invoke-Expression "C:\Windows\system32\Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore"
            $AnalyzeComponentStore = $AnalyzeComponentStore | Where-Object { $_.contains("Component Store Cleanup Recommended") } |
            Select-object -Property @{Name = "CleanupRecommended"; Expression = { $_.substring(38, 2) } }
        
            if (!($AnalyzeComponentStore.CleanupRecommended -eq "No")) {
                $logger.warning("Cleaning Up Windows Component Store")
                Write-output "Cleaning Up Windows Component Store"
                $StartComponentCleanup = Invoke-Expression "C:\Windows\system32\Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
                $logger.informational(" $StartComponentCleanup")
                $StartComponentCleanup
            }
            else {
                $logger.informational("Image Component Store does not need cleanup")
                Write-Output "Image Component Store does not need cleanup"
            }
            "---------------------------------------"
            
        }

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
    }
    
    process {
        # Test for the locked CBS log file
        if (Test-IsFileLocked) {
            Wait-Condition -condition { 
                $logger.informational("File $cbsPath is locked currently")
                Write-Output "File $cbsPath is locked currently"
                Try {
                    $logger.warning("Trying to stop TrustedInstaller Service")
                    Write-Output "Stopping TrustedInstaller Service"
                    Stop-Service -name "TrustedInstaller" -Force -ErrorAction Stop
                    (Get-Service -Name "TrustedInstaller").WaitForStatus('Stopped', '00:00:15')
                    $logger.informational("Stopped TrustedInstaller Service")
                }
                Catch {
                    $logger.error("$_.message Unable to stop the TrustedInstaller Service")
                    Write-Error "$_.message Unable to stop the TrustedInstaller Service"
                }
            } -Timeout 300 -ErrorAction Stop
        }
        
        # Test CBS log path and see if system was scanned before or not
        if (!(Test-Path -Path "$cbsPath")) {
            $logger.informational("$cbsPath has not been created yet. No scans have completed or have been run.")
            Write-Host "$cbsPath has not been created yet. No scans have completed or have been run." -ForegroundColor Red           
            Write-Verbose -Message "Creating CBS Logs..."
        }
        else {
            # Remove Logs older than five minutes and create new
            $logger.informational("CBS Logs are older than 5 minutes, Recreating...")
            Write-Output "CBS Logs are older than 5 minutes, Recreating..."
            Get-ChildItem -Path "$cbsPath" | Where-Object { $_.CreationTime -lt (Get-Date).AddMinutes($CBSLifeSpan) } | Remove-Item
            $logger.warning("Removing $cbsPath")
            Write-Output "Please be patient as this takes about 5-10 minutes..."
            Write-Verbose -Message "Recreating CBS Logs..."
        }
        
        $SFCResponses = Compare-SFCOuput
        ($SFCResponses | Where-Object { $_.bool -eq $true }).Description
       
        Show-CBSResults

        Wait-Condition -condition { Resolve-ReagentC }

        Wait-Condition -Condition { Resolve-ComponentStore } -Timeout 900
        
        Write-Warning -Message "Running Online Image Health Check"
        $logger.informational("Running Online Image Health Check")
        $imageCheckHealth = Repair-WindowsImage -Online -CheckHealth @logLevel
        if ($imageCheckHealth.ImageHealthState -ne "Healthy") {
            $logger.warning("Image Health Check Indicates Corruption...")
            Write-Warning -message "Image Health Check Indicates Corruption"
            $logger.informational("Running Online Image Health Scan")
            Write-Warning -Message "Running Online Image Health Scan"
            $imageScanHealth = Repair-WindowsImage -Online -ScanHealth @logLevel
            if ($imageScanHealth.ImageHealthState -ne "Healthy") {
                If ((Test-Internet) -ge $AcceptableRate) {
                    try {
                        # Restore health fixes component store corruption
                        Write-Verbose -Message "Running Online Image Health Restore..."
                        $logger.informational("Running Online Image Health Restore...")
                        $imageRestoreHealth = Repair-WindowsImage -Online -RestoreHealth @logLevel
                    }
                    catch {
                        Write-Host "Unable to finish Online Restore health. Use a local image as a source" -ForegroundColor Red
                        Write-Error -message "$_.Exception.Message"
                        $logger.error("Unable to finish Online Restore health. Use a local image as a source")
                        $logger.error("$_.Exception.Message")
                        $UseSource = $true
                    }
                }
                else {
                    $logger.warning("Connection to windows update is spotty. $SuccessPercent% success rate")
                    $logger.informational("Repair will proceed from a local image as a source.")
                    Write-Warning "Connection to windows update is spotty. $SuccessPercent% success rate"
                    Write-Host "Repair will proceed from a local image as a source." -ForegroundColor Red
                    $UseSource = $true
                }
            }
            ELSE {
                $SFCResponses = Compare-SFCOuput
                ($SFCResponses | Where-Object { $_.bool -eq $true }).Description
            }
        }

        #Dism /Online /Cleanup-Image /RestoreHealth /Source:esd:C:\$Windows.~BT\Sources\Install.esd:1 /limitaccess
        #Dism /Online /Cleanup-Image /RestoreHealth /Source:wim:D:\sources\install.wim:1 /limitaccess
        if (($UseSource) -or (($SFCResponses)[0].bool -eq $False)) {
            Write-Verbose -Message "Initializing Image Source Mounting"
            $logger.informational("Initializing Image Source Mounting")
            foreach ($imageSource in $imageSources) {
                if (!([string]::IsNullOrWhiteSpace($imageSource))) {
                    if ($imageSource -like "*ISO" ) {
                        # Copy iso
                        $logger.informational("Downloading $imageSource...")
                        #Start-BitsTransfer -Source $imageSource -Destination "$home\downloads\Windows.iso" -Description "download install wim file"

                        # Find the Drive letter to mounted image
                        $logger.informational("Mounting Image Source...")
                        $mountedDrive = Mount-DiskImage -ImagePath $imageSource -PassThru | Get-DiskImage | Get-Volume
                        

                        # Find full path to ESD or WIM
                        $logger.informational("Resolving full path to Image Source...")
                        $mountedImageSource = Get-ChildItem -Path "$($mountedDrive.DriveLetter):\" -Recurse | Where-Object { ($_.Name -like "Install.esd" -or $_.name -like "Install.Wim") } |
                        Select-Object -ExpandProperty FullName

                        # Find the correct index to the current system
                        $logger.informational("Indexing Source...")
                        $windowsIndex = Get-WindowsImage -ImagePath "$mountedImageSource" | 
                        Where-Object { ($_.imageName -match "$winProductName" -and $_.imageName -notlike "$winProductName N" ) } | 
                        Sort-Object imageName | Select-Object -First 1

                        Write-Verbose -Message "Using $mountedImageSource as source to repair component store corruption"
                        try {
                            $logger.informational("Starting Windows Repair...")
                            Repair-WindowsImage -Online -RestoreHealth -LimitAccess -Source "$($mountedImageSource):$($windowsIndex.ImageIndex)" @logLevel
                        }
                        catch {
                            $logger.error("$_.Exception.Message")
                            Write-Host "$_.Exception.Message" -ForegroundColor Red
                        }

                        Dismount-DiskImage -ImagePath $imageSource                        
                    }
                    else {
                        $logger.informational("Downloading $imageSource...")
                        Start-BitsTransfer -Source $imageSource -Destination "$home\downloads\install.wim" -Description "download install wim file"

                        $logger.informational("Resolving full path to Image Source...")
                        $copiedSource = get-childitem -path "$home\downloads\install.wim"

                        $logger.informational("Indexing Source...")
                        $windowsIndex = Get-WindowsImage -ImagePath $copiedSource | 
                        Where-Object { ($_.imageName -match "$winProductName" -and $_.imageName -notlike "$winProductName N" ) } |
                        Sort-Object imageName | Select-Object -First 1

                        try {
                            $logger.informational("Starting Windows Repair...")
                            Write-Verbose -Message "Using $imageSource as source to repair component store corruption"
                            Repair-WindowsImage -Online -RestoreHealth -LimitAccess -Source "$($imageSource):$($windowsIndex.ImageIndex)" @logLevel -ErrorAction Stop
                        }
                        catch {
                            $logger.error("$_.Exception.Message")
                            Write-Host "$_.Exception.Message" -ForegroundColor Red
                        }

                    } 
                }
                else {
                    $logger.warning("Image source was either null or does not exist")
                    Write-Warning -Message "Image source was either null or does not exist"
                }
                $imageCheckHealth = Repair-WindowsImage -Online -CheckHealth @logLevel
                if (($imageCheckHealth.ImageHealthState -ne "healthy") -or (($SFCResponses)[0].bool -eq $False)) {
                    $logger.Notice("Trying Second Image Source...")
                }
                else {
                    $logger.informational("Image report came back as healthy. Breaking Loop.")
                    break
                }
            }
            $SFCResponses = Compare-SFCOuput
            ($SFCResponses | Where-Object { $_.bool -eq $true }).Description
            Show-CBSResults   
        }
        ELSE {
            $logger.informational("Online Image Health Check Has No Indication of Corruption")
            Write-Host "Online Image Health Check Has No Indication of Corruption" -ForegroundColor Green
        }
    }
    end {
        "---------------------------------------"
        switch ($imageCheckHealth.ImageHealthState) {
            Healthy { $logger.informational("Image is $($imageCheckHealth.ImageHealthState)") }
            Default { $logger.Alert("Image is $($imageCheckHealth.ImageHealthState)") }
        }
        $imageCheckHealth
        
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        Write-Output "Repair-Image Script has Completed"
        $scriptTimer.stop()
        $logger.informational("Script Runtime:$($scriptTimer.Elapsed.ToString())")
        Start-Sleep -Seconds 7
    }
}