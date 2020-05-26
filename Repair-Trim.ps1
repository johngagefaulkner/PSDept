function Repair-Trim {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DriveLetter = "C",

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
        $checkTrimmedDrives = fsutil behavior query DisableDeleteNotify
    }
    
    process {
        foreach ($trimmedDrive in $checkTrimmedDrives) {
            if (!($trimmedDrive -match '0' )) {
                Write-Verbose -Message "Enabling Trim Function..."
                $logger.notice("Enabling Trim Function...") 
                [void](fsutil behavior set DisableDeleteNotify 0)
            }
        }
        Write-verbose "Invoking analysis on ($($DriveLetter):)..."
        $logger.informational("Invoking analysis on ($($DriveLetter):)...") 
        # Merge stream 4 (Verbose) into standard Output stream
        $analysis = & { Optimize-Volume -DriveLetter $DriveLetter -Analyze -Verbose } 4>&1
        # Check the "Message" property of the very last VerboseRecord in the output
        if ($analysis[-1].Message -like "*It is recommended*") {
            # Trim Drive
            Write-verbose -message "Optimizing Volume $($DriveLetter): Performing Retrim..."
            $logger.notice("Optimizing Volume $($DriveLetter): Performing Retrim...") 
            Optimize-Volume -DriveLetter $DriveLetter -Verbose
        }
        else {
            $logger.informational("Analysis of Volume $($DriveLetter): Complete") 
            Write-verbose -message "Analysis of Volume $($DriveLetter): Complete"
        }
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
