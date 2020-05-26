function Reset-WSUS {
    <#
    .SYNOPSIS
        Repairs the connection for WSUS to client machines after imaging

    .DESCRIPTION
        Repairs the connection for WSUS to client machines after imaging

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .PARAMETER SecondParameter
        Description of each of the parameters.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Reset-WSUS

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
        [String]$LogPath = "C:\Temp"
    )

    begin {
        $kasperskyLocal = "C:\Program Files (x86)\Kaspersky Lab"
        $wsusRegLocation = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate"

        $ResetWSUS = [Diagnostics.Stopwatch]::StartNew()
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        $services = @(
            "wuauserv",
            "cryptSvc",
            "bits",
            "msiserver"
        )

        $wsusRegs = @(
            "PingID",
            "AccountDomainSid",
            "SusClientId",
            "SusClientIDValidation"
        )

        $wsusDLLs = @(
            "msxml3.dll",
            "wups.dll",
            "wuapi.dll",
            "wuaueng.dll",
            "wucltui.dll"
        )

        $wsusFiles = @(
            "c:\windows\windowsupdate.log",
            "c:\windows\softwaredistribution",
            "C:\Windows\System32\catroot2"
        )
    }
    
    process {
        if (Get-Service -Name AVP -ErrorAction SilentlyContinue) {
            If ((Get-Service -Name AVP).Status -eq "Running") {
                $logger.error("AVP Service is already running")
                Write-host "AVP Service is already running" -ForegroundColor Red

                $logger.error("Some files may not be removed. Please stop the AVP service if you need to fix WSUS Machine ID.")
                Write-host "Some files may not be removed. Please stop the AVP service if you need to fix WSUS Machine ID." -ForegroundColor Red

                $logger.error("Stopping Reset-WSUS Function")
                Write-host "Stopping Reset-WSUS Function" -ForegroundColor Red
                exit
            }
            else {
                $logger.informational("Service 'AVP' Found, but is not running, continuing")
                Write-Output "Service 'AVP' Found, but is not running, continuing"
            }
        }
        else {
            $logger.Notice("Cannot find any service with service name 'AVP', continuing ")
            Write-Output "Cannot find any service with service name 'AVP', continuing "
        }
        
        $logger.informational("Stopping Services...")
        Write-Warning -Message "Stopping Services..."
        Write-Output "-----------------------------------"
        foreach ($service in $services) {
            Try {
                Stop-Service -name "$service" -Force -ErrorAction Stop
                $logger.informational("Stopped $service Service")
                write-host "Stopped $service Service" -ForegroundColor green
            }
            Catch {
                $logger.warning("Unable to Stop $service Service")
                write-host "Unable to Stop $service Service" -ForegroundColor Red
            }
        }

        Write-Output ""
        $logger.informational("Removing Registries...")
        Write-Warning -Message "Removing Registries..."
        Write-Output "-----------------------------------"    
        foreach ($wsusReg in $wsusRegs) {
            if (Get-ItemProperty -Path "$wsusRegLocation" -name "$wsusReg" -ErrorAction SilentlyContinue) {
                Try {
                    Remove-ItemProperty -Path "$wsusRegLocation" -Name "$wsusReg" | Out-Null
                    $logger.informational("Removed $wsusReg Registry")
                    write-Host "Removed $wsusReg Registry" -ForegroundColor green
                }
                Catch {
                    $logger.warning("Unable to remove registry $wsusReg")
                    write-host "Unable to remove registry $wsusReg" -ForegroundColor Red
                }
            }
        }

        Write-Output ""
        $logger.informational("Registering DLL's...")
        Write-Warning -Message "Registering DLL's..."
        Write-Output "-----------------------------------"
        foreach ($wsusDLL in $wsusDLLs) {
            Try {
                regsvr32 /s "$wsusDLL"
                $logger.informational("Registered $wsusDLL")
                write-host "Registered $wsusDLL" -ForegroundColor green
            }
            Catch {
                $logger.warning("Unable to register $wsusDLL")
                write-host "Unable to register $wsusDLL" -ForegroundColor Red
            }
        }

        start-sleep -seconds 7
        Write-Output ""
        $logger.informational("Removing WSUS Files...")
        Write-Warning -Message "Removing WSUS Files..."
        Write-Output "-----------------------------------"   
        foreach ($wsusFile in $wsusFiles) {
            if (Test-Path -Path "$wsusFile") {
                Try {
                    Remove-Item -Path "$wsusFile" -Recurse -Force -ErrorAction Stop
                    $logger.informational("removed $wsusFile file or files")
                    write-host "removed $wsusFile file or files" -ForegroundColor green
                }
                Catch {
                    $logger.warning("Unable to remove file or files in $wsusFile")   
                    write-host "Unable to remove file or files in $wsusFile" -ForegroundColor Red
                }
            }
        }

        Write-Output ""
        $logger.informational("Starting Services...")
        Write-Warning -Message "Starting Services..."
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
                    write-host "Started $service Service" -ForegroundColor green
                }
            }
            Catch {
                $logger.warning("Unable to start $service Service")
                write-host "Unable to start $service Service" -ForegroundColor Red
            }
        }
        
    }
    end {
        Invoke-Expression "C:\Windows\System32\wuauclt.exe /resetauthorization /detectnow"
        $logger.informational('Invoking Expression "C:\Windows\System32\wuauclt.exe /resetauthorization /detectnow"') 

        (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
        $logger.informational('Invoking Expression "(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()"') 

        Write-Verbose -Message "Resetting WSUS Authorization/Connection" -Verbose
        $logger.Notice("$($MyInvocation.MyCommand) has Finished")
        
        $ResetWSUS.stop()
        $logger.informational("Script Runtime:$($ResetWSUS.Elapsed.ToString())")
    }
}
Reset-WSUS