function Initialize-WindowsBenchMarking {
    <#
    .SYNOPSIS
        Starts the windows benchmarking.

    .DESCRIPTION
        Removes the older performance files and then runs the windows benchmarking. Grabs the benchmark results.

    .PARAMETER PerformanceXMLPath
        Path to the windows xml path. Default is C:\Windows\Performance\WinSAT\DataStore\*.

    .PARAMETER Minutes
        The amount of minutes you want to start going back to check for files for removal. Default is -10.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Initialize-WindowsBenchMarking
    
    .EXAMPLE
        Initialize-WindowsBenchMarking -Minutes -20

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String]$PerformanceXMLPath = "C:\Windows\Performance\WinSAT\DataStore\*",

        [Parameter(Mandatory=$false)]
        [int]$Minutes = -10,

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
        
        $winStats = (Get-CimInstance 'Win32_WinSat')

        # Remove items more than 5 mins old
        #laptop has to be plugged in to run formal test
        try {
            (Get-ChildItem -Path $PerformanceXMLPath).where{ $_.CreationTime -lt ((Get-Date).AddMinutes($Minutes)) } | Remove-Item
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Error -Message "File path $_ not found"
            $logger.error("File path $_ not found") 
        }
        catch [System.IO.IOException] {
            Write-Error -Message  "File $_ may be open at time of deletion"
            $logger.error("File $_ may be open at time of deletion")  
        }
        Catch [System.UnauthorizedAccessException] {
            Write-Error -Message  "$_ Access Denied"
            $logger.error("$_ Access Denied") 
        }
        catch {
            Write-Error -Message "$_.Exception.Message"
            $logger.error("$_.Exception.Message")  
        }        
    }
    
    process {
        # if item is null then rerun formal with computer name
        try {
            $performanceXML = (Get-ChildItem -Path $PerformanceXMLPath)
            if ($null -eq $performanceXML) {
                Write-Warning -Message "Benchmarking in progress..."
                start-process "C:\Windows\System32\WinSAT.exe" -ArgumentList "formal -icn" -NoNewWindow -Wait
                $winStats = (Get-CimInstance 'Win32_WinSat')
            }    
        }
        catch {
            Write-Error -Message "$_.Exception.Message"
            $logger.error("$_.Exception.Message") 
        }

        # Get latest formal item and uses that as time taken
        try {
            $TimeTaken = (Get-ChildItem -Path $PerformanceXMLPath).where{ $_.name -like "*Formal.Assessment*.xml" } | 
            Sort-object LastWriteTime -Descending | Select-Object -ExpandProperty lastwritetime -First 1
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Error -Message "File path $_ not found"
            $logger.error("File path $_ not found")  
        }
        catch [System.IO.IOException] {
            Write-Error -Message  "File $_ may be open at time of Access"
            $logger.error("File $_ may be open at time of Access")  
        }
        Catch [System.UnauthorizedAccessException] {
            Write-Error -Message  "$_ Access Denied"
            $logger.error("$_ Access Denied") 
        }
        catch {
            Write-Error -Message "$_.Exception.Message"
            $logger.error("$_.Exception.Message")  
        }
    }
    
    end {
        $MachineBenchmarks = [PSCustomObject]@{
            Message        = "Machine Benchmarks"
            CPUScore       = $winStats.CPUScore
            D3DScore       = $winStats.D3DScore
            DiskScore      = $winStats.DiskScore
            GraphicsScore  = $winStats.GraphicsScore
            MemoryScore    = $winStats.MemoryScore
            TimeTaken      = $timeTaken
            WinSPRLevel    = $winStats.WinSPRLevel
            PSComputerName = $env:COMPUTERNAME
        }
        $MachineBenchmarks
        $logger.informational("$MachineBenchmarks")
        
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
