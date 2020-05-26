function Test-DiskPerformance {
    <#
    .SYNOPSIS
        A hashtable of disk performance tests that are run against the main drive.

    .DESCRIPTION
        A hashtable of disk performance tests that are run against the main drive.

    .PARAMETER Path
        Path to the diskspd.exe

    .PARAMETER XMLProfile
        Path to a xml profile

    .PARAMETER Destination
        Destination to copy the item.

    .PARAMETER LogPath
         Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Example of how to run the script.

    .LINK
        https://github.com/microsoft/diskspd/wiki/Command-line-and-parameters
        https://github.com/Microsoft/diskspd/wiki/Customizing-tests
        https://github.com/Microsoft/diskspd/wiki/Analyzing-test-results.

    .NOTES
        Detail on what the script does, if this is needed.
    #>
        [CmdletBinding()]
        [Alias()]
        [OutputType([String])]
        Param (
            [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true)]
            [ValidateScript( {
                    if (-Not ($_ | Test-Path) ) {
                        throw "File does not exist"
                    }
                    if (-Not ($_ | Test-Path -PathType Leaf) ) {
                        throw "The path argument must be a file. Folder paths are not allowed."
                    }
                    if ($_ -notmatch "(\.exe)") {
                        throw "The file specified in the path argument must be .exe"
                    }
                    return $true 
                })]
            [string]$Path = "\\Server\Path\Here\Benchmark\DiskSpd\amd64\diskspd.exe",
    
            [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true)]
            [ValidateScript( {
                    if (-Not ($_ | Test-Path) ) {
                        throw "File does not exist"
                    }
                    if (-Not ($_ | Test-Path -PathType Leaf) ) {
                        throw "The path argument must be a file. Folder paths are not allowed."
                    }
                    if ($_ -notmatch "(\.xml)") {
                        throw "The file specified in the path argument must be .xml"
                    }
                    return $true 
                })]
            [string[]]$XMLProfile,
            
            [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true)]
            [String]$Destination = "$home\Downloads",
            
            [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [String]$LogPath = "C:\Temp"
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
    
            # Copy and import the needed info
            try {
                if (!(Test-Path -Path "$Destination\DISKSPEED")) {
                    Write-Output "Creating DISKSPEED in $Destination"
                    $logger.informational("Creating DISKSPEED in $Destination")
                    [void](New-Item -path "$Destination\DISKSPEED" -ItemType directory -force)
                }
    
                $logger.informational("$Path to $Destination\DISKSPEED")
                Copy-Item -Path $Path, "\\Server\Path\Here\Benchmark\diskspd-master\Process-DiskSpd.ps1" -Destination "$Destination\DISKSPEED"
            }
            catch {
                $logger.Error("$PSitem")
                $PSCmdlet.ThrowTerminatingError($PSitem)
            }
    
            $driveTest = @(
                @{Output = "Large area random concurrent reads of 4KB blocks" ; ArgList = @("-c50M", "-b8K","-d60","-h","-L","-o2","-t4","-r","-w30","-Rxml","$Destination\DISKSPEED\testfile.dat")}
                @{Output = "Large area random concurrent writes of 4KB blocks" ; ArgList = @("-c750M","-w100","-b4K","-F8","-o2","-r","-o32","-W10", "-d60","-Rxml","-Sh", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area random serial reads of 4KB blocks." ; ArgList = @("-c750M", "-b4K", "-r", "-o1", "-W10", "-d60", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area random serial writes of 4KB blocks" ; ArgList = @("-c750M", "-w100", "-b4K", "-r", "-o1", "-W10", "-d30", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area sequential concurrent reads of 4KB blocks" ; ArgList = @("-c750M", "-b4K", "-F8", "-T1b", "-s8b", "-o32", "-W10", "-d30", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area sequential concurrent writes of 4KB blocks" ; ArgList = @("-c750M", "-w100", "-b4K", "-F8", "-T1b", "-s8b", "-o32", "-W10", "-d30", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area sequential serial reads of 4KB blocks" ; ArgList = @("-c750M", "-b4K", "-o1", "-W10", "-d30", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Large area sequential serial writes of 4KB blocks" ; ArgList = @("-c750M", "-w100", "-b4K", "-o1", "-W10", "-d30", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Small area concurrent reads of 4KB blocks" ; ArgList = @("-c100b", "-b4K", "-o32", "-F8", "-T1b", "-s8b", "-W10", "-d60", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")},
                @{Output = "Small area concurrent writes of 4KB blocks" ; ArgList = @("-c100b", "-w100", "-b4K", "-o32", "-F8", "-T1b", "-s8b", "-W10", "-d60", "-Sh","-Rxml", "$Destination\DISKSPEED\testfile.dat")}
                #@{Output = "Display statstics about physical disk I/O and memory events from the NT Kernel Logger" ; ArgList = @("-eDISK_IO", "-eMEMORY_PAGE_FAULTS", "$Destination\DISKSPEED\testfile.dat")}
            )
    
            $logger.informational("Setting location to $Destination\DISKSPEED")
            Set-Location ("$Destination\DISKSPEED")
        }
        
        process {
        
            try {
                Write-Verbose "Starting Disk Testing..."
                if ($XMLProfile){
                    foreach ($profile in $XMLProfile) {
                        $logger.informational("Starting $profile Profile...")
                        .\diskspd.exe "-x $profile"
                    }
                } else {
                    foreach ($test in $driveTest) {
                        $logger.informational("Starting $($test.output)...")
                        Write-Output "Starting $($test.output)"
                        (.\diskspd $test.ArgList) | out-file -filepath "$Destinations\DISKSPEED\$($test.output).xml"
                    }
                }
            }
            catch {
                $logger.Error("$PSitem")
                $PSCmdlet.ThrowTerminatingError($PSitem)
            }
            #."$Destinations\DISKSPEED\process-diskspd" -xmlresultpath "$Destinations\DISKSPEED\"
        }
        
        end {
            Write-Verbose "Disk Testing Completed"
            $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        }
}