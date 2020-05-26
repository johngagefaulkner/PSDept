function Repair-DriveSector {
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
    }
    
    process {
        Write-Verbose -Message "Checking for drive corruption..." -Verbose
        $logger.informational("Checking for drive corruption...")
        $checkDisk = Repair-Volume -DriveLetter $DriveLetter -Scan

        if (!($checkDisk -like "NoErrorsFound")) {
            $logger.Warning("Fixing drive corruption...")
            Write-Verbose -Message "Fixing drive corruption..." -Verbose
            Repair-Volume -DriveLetter $DriveLetter -SpotFix
        }
        else {
            $logger.informational("No Drive Corruption Found")
            Write-Verbose -Message "No Drive Corruption Found" -Verbose
        }
        
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
