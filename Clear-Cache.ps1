function Clear-Cache {
    <#
    .SYNOPSIS
        Clears Cache for Edge,Firefox,Google Chrome, Internet Explorer, Windows, Windows Credentials, Windows Store, Office,
        Recycle Bin, DNS, logs, and Previous installation files
    .DESCRIPTION
        Clears Cache for Edge,Firefox,Google Chrome, Internet Explorer, Windows, Windows Credentials, Windows Store, Office,
        Recycle Bin, DNS, logs, and Previous installation files
        Cache\*"
        Cookies*"
        History*"
        Login Data*"
        Top Sites*"
        Visited Links"
        Web Data*"
        "C:\Windows\MEMORY.dmp",
        "C:\Windows\Minidump\*.dmp",
        "$env:temp",
        "c:\windows\windowsupdate.log",
        "c:\windows\softwaredistribution",
        "C:\Windows\System32\catroot2"
        "C:\Temp\Deployment_Log"
        "C:\Windows\Logs\CBS\*"
        Recent items
        AutomaticDestinations
        CustomDestinations
        and more.

    .PARAMETER Online
        Runs Online of the items needed for a machine in use.

    .PARAMETER Image
        Runs everything in 'Online' and a start component cleanup reset base. A Build check that will warn you once 
        there has been more than 2 upgrades applied to windows 10.
        
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        PS C:\> Clear-Cache
        Clears everything but previous installation files and restore points

        PS C:\> Clear-Cache -Online
        Clears everything with previous installation files but not restore points

        PS C:\> Clear-Cache -Image
        Clears everything with previous installation files and restore points

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ParameterSetName = 'ForceAllClear', Mandatory = $false)]
        [switch]$Online,

        [Parameter(Position = 1, ParameterSetName = 'ForceAllClear', Mandatory = $false)]
        [switch]$Image,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        $scriptTimer = [Diagnostics.Stopwatch]::StartNew()

        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath, $callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        # Main Folder Locations
        $edgeLocal = "$($env:LOCALAPPDATA)\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
        $fireFoxLocal = "$($env:LOCALAPPDATA)\Mozilla\Firefox\Profiles\*.default-release"
        $fireFoxRoaming = "$($env:APPDATA)\Mozilla\Firefox\Profiles\*.default-release"
        $edgeChromeLocal = "$($env:LOCALAPPDATA)\Microsoft\Edge\User Data\Default"
        $googleChromeLocal = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default"
        $internetExplorerLocal = "$($env:LOCALAPPDATA)\Microsoft\Windows"

        # Edge Cache Locations
        $edgeCaches = @(
            "$edgeLocal\TempState\Downloads\*",
            "$edgeLocal\AppData\User\Default\CacheStorage\CacheStorage.edb",
            "$edgeLocal\AppData\User\Default\Indexed DB\IndexedDB.edb",    
            "$edgeLocal\LocalState\Favicons\TopSites\*"
            "$edgeLocal\AC\#!001\MicrosoftEdge\*"
            "$edgeLocal\AC\#!002\MicrosoftEdge\*"
        )

        $EdgeChromeCaches = @(
            "$edgeChromeLocal\Cache\*",
            "$edgeChromeLocal\Code Cache\js\*_0*",
            "$edgeChromeLocal\Cookies*",
            "$edgeChromeLocal\History*",
            "$edgeChromeLocal\Login Data*",
            "$edgeChromeLocal\Top Sites*",
            "$edgeChromeLocal\Visited Links",
            "$edgeChromeLocal\Web Data*"            
        )

        # FireFox Cache Locations
        $fireFoxCaches = @(
            "$fireFoxLocal\activity-stream.topstories*",
            "$fireFoxRoaming\addonStartup.json.lz4",
            "$fireFoxRoaming\AlternateServices.txt",
            "$fireFoxRoaming\broadcast-listeners.json",
            "$fireFoxLocal\cache2\*",
            "$fireFoxRoaming\cookies.sqlite*",
            "$fireFoxRoaming\crashes\*",
            "$fireFoxRoaming\datareporting\*",
            "$fireFoxRoaming\enumerate_devices.txt",
            #"$fireFoxRoaming\favicons.sqlite*",
            "$fireFoxRoaming\formhistory.sqlite",
            "$fireFoxRoaming\gmp\*",
            "$fireFoxLocal\jumpListCache\*",
            "$fireFoxLocal\OfflineCache\*",
            #"$fireFoxRoaming\parent.lock",
            #"$fireFoxRoaming\places.sqlite*",
            #"$fireFoxRoaming\prefs.js",
            "$fireFoxLocal\safebrowsing\*",
            "$fireFoxRoaming\saved-telemetry-pings\*",
            "$fireFoxRoaming\SecurityPreloadState.txt",
            "$fireFoxRoaming\sessionCheckpoints.json",
            "$fireFoxRoaming\sessionstore.jsonlz4",
            #"$fireFoxRoaming\sessionstore-backups\*",
            "$fireFoxRoaming\SiteSecurityServiceState.txt",
            "$fireFoxLocal\thumbnails\*",
            "$fireFoxRoaming\TRRBlacklist.txt",
            "$fireFoxLocal\startupCache\urlCache.bin",
            "$fireFoxRoaming\weave\*",
            "$fireFoxRoaming\webappsstore.sqlite*",
            "$fireFoxRoaming\xulstore.json"
        )

        # Google Chrome Cache Locations
        $googleChromeCaches = @(
            "$googleChromeLocal\Cache\*",
            "$googleChromeLocal\Code Cache\js\*_0*",
            "$googleChromeLocal\Cookies*",
            "$googleChromeLocal\History*",
            "$googleChromeLocal\Login Data*",
            "$googleChromeLocal\Top Sites*",
            "$googleChromeLocal\Visited Links",
            "$googleChromeLocal\Web Data*"            
        )

        # Internet Explorer Cache Locations
        $internetExplorerCaches = @(
            "$internetExplorerLocal\History",
            "$internetExplorerLocal\INetCookies",
            "$internetExplorerLocal\INetCache"
        )

        $officeCache = Get-ChildItem -Path "$($env:LOCALAPPDATA)\Microsoft\Office\" |
        Where-Object { $_.BaseName -match '\d\d[.]\d' } | 
        Sort-Object LastWriteTime | Select-Object -last 1


        # Windows Cache Locations
        $windowsCaches = @(
            "$env:SystemRoot\MEMORY.dmp",
            "$env:SystemRoot\Minidump\*.dmp",
            "$env:temp",
            "$env:SystemRoot\windowsupdate.log",
            "$env:SystemRoot\softwaredistribution",
            "$env:SystemRoot\System32\catroot2",
            "$env:SystemDrive\Temp\Deployment_Log",
            "$env:SystemRoot\Logs\CBS\*",
            "$env:APPDATA\Recent\*",
            "$env:APPDATA\Recent\AutomaticDestinations\*",
            "$env:APPDATA\Recent\CustomDestinations\*",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive\*",
            "$env:ALLUSERSPROFILE\Lenovo\SystemUpdate\sessionSE\Repository\*",
            "$env:ALLUSERSPROFILE\Dell\*",
            "$env:ALLUSERSPROFILE\Synaptics\*.etl"
        )

        $services = @(
            "wuauserv",
            "cryptSvc",
            "bits",
            "msiserver",
            "TrustedInstaller"
        )

        $CleanupLocations = @(
            @{Name = "Microsoft Edge" ; Cache = $edgeCaches; Process = "MicrosoftEdge" },
            @{Name = "Microsoft Edge Chrome" ; Cache = $EdgeChromeCaches; Process = "msedge" },
            @{Name = "FireFox" ; Cache = $fireFoxCaches; Process = "firefox" },
            @{Name = "Google Chrome" ; Cache = $googleChromeCaches; Process = "chrome" },
            @{Name = "Internet Explorer" ; Cache = $internetExplorerCaches; Process = "iexplore" },
            @{Name = "Office" ; Cache = "$($officeCache.fullname)\OfficeFileCache" ; Process = "MSOUC" }
            @{Name = "Windows" ; Cache = $windowsCaches ; Process = "" }
        )
    }
    
    process {
        # Stops services related to the software distribution folder
        Write-Warning -Message "Stopping Services..."
        $logger.Warning("Stopping Services...")
        Write-Output "-----------------------------------"
        foreach ($service in $services) {
            Try {
                Stop-Service -name "$service" -Force -ErrorAction Stop
                $logger.informational("Stopped $service Service")
                Write-Host "Stopped $service Service" -ForegroundColor green
            }
            Catch {
                $logger.Notice("Unable to Stop $service Service")
                Write-Host "Unable to Stop $service Service" -ForegroundColor Red
            }
        }

        # Close Browsers
        Write-Verbose -Message "Closing Browsers..."
        $logger.informational("Closing Browsers...")
        foreach ($process in $($cleanupLocations.process)) {
            if (!([string]::IsNullOrWhiteSpace($process))) {
                while (Get-Process -Name $process -ErrorAction SilentlyContinue ) {
                    $logger.informational("Closing browser process: $process...")
                    Get-Process -Name $process | Stop-Process -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 1500
                }
            }            
        }

        # Secondary IE Clear
        $logger.informational("Invoking ClearMyTracksByProcess option 9")
        Invoke-Expression -Command "RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 9"

        # Low Level IL Internet Explorer Clear
        $logger.informational("Creating $env:temp\RUNDLL32-IL.EXE ")
        Copy-Item -Path "C:\Windows\system32\RUNDLL32.EXE" -Destination "$env:temp\RUNDLL32-IL.EXE"
        $logger.informational("Setting $env:temp\RUNDLL32-IL.EXE INTEGRITY LEVEL LOW")
        ICACLS $env:temp\RUNDLL32-IL.EXE /SETINTEGRITYLEVEL LOW
        If (!(Test-Path -Path "$env:temp\rundll32.vbs")) {
            $VBS = @{
                path     = "$env:temp"
                Name     = "rundll32.vbs"
                ItemType = "file"
                Value    = 'createobject("shell.application").shellexecute "cmd.exe",""" /c START /W /B %tmp%\RunDll32-IL.exe InetCpl.cpl,ClearMyTracksByProcess 255""","","runas",0'
            }
            $logger.informational("Building Custom VBS...")
            [void](New-Item @VBS)
        }        

        # Foreach Cache location, Remove items
        Write-Verbose -Message "Clearing Caches..."
        Start-Job -Name "rundll32-Low" -ScriptBlock { Start-Process -FilePath "$env:temp\rundll32.vbs" -Wait }
        foreach ($cleanupLocation in $cleanupLocations) {
            $logger.informational("Starting $($cleanupLocation.name) job")
            Start-Job -Name "$($cleanupLocation.name)" -ScriptBlock {
                if (!([string]::IsNullOrWhiteSpace($cleanupLocation.cache))) {
                    foreach ($cache in $($cleanupLocation.cache)) {
                        if (Test-Path -Path "$cache") {
                            $logger.informational("Removing $cache...")
                            Remove-Item -Path "$cache" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }

        # Starts services related to the software distribution folder
        Write-Output ""
        Write-Warning -Message "Starting Services..."
        $logger.informational("Starting Services...")
        Write-Output "-----------------------------------"   
        foreach ($service in $services) {
            Try {
                If ((Get-Service "$service").status -eq "Running") {
                    $logger.informational("$service is already running")
                    Write-Host "$service is already running" -ForegroundColor Green
                    
                }
                else {
                    Start-Service -name "$service" -ErrorAction Stop
                    $logger.informational("Started $service Service")
                    Write-Host "Started $service Service" -ForegroundColor green
                }
            }
            Catch {
                $logger.Warning("Unable to start $service Service")
                Write-Host "Unable to start $service Service" -ForegroundColor Red
            }
        }

        # Clears Windows store cache
        if (Test-Path -Path "C:\Windows\System32\WSReset.exe") {
            $logger.informational("Clearing Windows Store Cache")
            Write-Output "Clearing Windows Store Cache"

            Start-Process -FilePath "C:\Windows\System32\WSReset.exe" -NoNewWindow -Wait
            Get-Process -Name "WinStore.App" | Stop-Process -Force
        }

        $logger.informational("Clearing RecycleBin")
        Clear-RecycleBin -Force
        
        $logger.informational("Clearing Dns Client Cache")
        Clear-DnsClientCache

        $logger.informational("Clearing Event Logs")
        (Get-EventLog -LogName *).ForEach( { Clear-EventLog $_.Log -ea SilentlyContinue })

        if ($Online -or $Image) {
            $logger.informational("Creating Cleanmgr profile, Starting Disk Cleanup utility...")
            Write-Output "Starting Disk Cleanup utility..."

            $ErrorActionPreference = "SilentlyContinue"
            $CleanMgrKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            $settings = @{
                Name  = 'StateFlags0001'
                Type  = 'DWORD'
                Value = 2
            }
            $paths = @(
                "Active Setup Temp Folders",
                "BranchCache",
                "Downloaded Program Files",
                "Internet Cache Files",
                "Memory Dump Files",
                "Old ChkDsk Files",
                "Previous Installations",
                "Recycle Bin",
                "Service Pack Cleanup",
                "Setup Log Files",
                "System error memory dump files",
                "System error minidump files",
                "Temporary Files",
                "Temporary Setup Files",
                "Thumbnail Cache",
                "Update Cleanup",
                "Upgrade Discarded Files",
                "User file versions",
                "Windows Defender",
                "Windows Error Reporting Archive Files",
                "Windows Error Reporting Queue Files",
                "Windows Error Reporting System Archive Files",
                "Windows Error Reporting System Queue Files",
                "Windows ESD installation files",
                "Windows Upgrade Log Files"
            )
            if (-not (Get-ItemProperty -path "$CleanMgrKey\Temporary Files" -name $settings.name)) {
                foreach ($path in $paths) {
                    $logger.informational("Setting $CleanMgrKey\$path Dword $($settings.Name) to value $($settings.value)")
                    Set-ItemProperty -path "$CleanMgrKey\$path" @Settings
                }
            }

            $logger.informational("Starting Cleanmgr with full set of checkmarks (might take a while)...")
            Write-Output "Starting Cleanmgr with full set of checkmarks (might take a while)..."

            $Process = (Start-Process -FilePath "$env:systemroot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -PassThru)
            
            $logger.informational("Process ended with exitcode [$($Process.ExitCode)].") 
            Write-Output "Process ended with exitcode [$($Process.ExitCode)]."

            $logger.informational("Clearing Windows Credentials...")
            cmdkey /list | ForEach-Object{if($_ -like "*Target:*"){cmdkey /del:($_ -replace " ","" -replace "Target:","")}}

        }

        if ($Image) {
            $logger.informational("Running command [C:\Windows\system32\Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase]")
            Invoke-Expression "C:\Windows\system32\Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase"

            $logger.informational("Clearing old restore points...")
            Start-Process -FilePath "vssadmin.exe" -ArgumentList "delete shadows /For=C: /oldest /quiet" -Wait
            
            $AllBuilds = $(Get-ChildItem "HKLM:\System\Setup" | Where-Object { $_.Name -match "\\Source\s" }) | 
            ForEach-Object { $_ | 
                Select-Object @{n = "UpdateTime"; e = { if ($_.Name -match "Updated\son\s(\d{1,2}\/\d{1,2}\/\d{4}\s\d{2}:\d{2}:\d{2})\)$") { [dateTime]::Parse($Matches[1], ([Globalization.CultureInfo]::CreateSpecificCulture('en-US'))) } } }, @{n = "ReleaseID"; e = { $_.GetValue("ReleaseID") } }, @{n = "Branch"; e = { $_.GetValue("BuildBranch") } }, @{n = "Build"; e = { $_.GetValue("CurrentBuild") } }, @{n = "ProductName"; e = { $_.GetValue("ProductName") } }, @{n = "InstallTime"; e = { [datetime]::FromFileTime($_.GetValue("InstallTime")) } } };
            
            if (($AllBuilds).count -gt 2) {
                $logger.Alert("Image has been upgraded more than 2 times. Consider rebuilding the entire image. [TotalUpgrades:$($AllBuilds.count)]")
                Write-Warning -Message "Image has been upgraded more than 2 times. Consider rebuilding the entire image. [TotalUpgrades:$($AllBuilds.count)]"
                $AllBuilds | Sort-Object UpdateTime | Format-Table UpdateTime, Build, ReleaseID, Branch, ProductName
            }
        }
    }
    
    end {
        # Process and Job Cleanup
        Stop-Process -Name "RUNDLL32-IL" -Force
        Get-Job | Wait-Job | Remove-Job
        
        Write-Output "Clear-Cache has finished"
        $scriptTimer.stop()
        $logger.informational("Script Runtime:$($scriptTimer.Elapsed.ToString())")
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")

    }
}