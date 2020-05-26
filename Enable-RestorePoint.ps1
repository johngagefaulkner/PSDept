function Enable-RestorePoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        Write-Output "Enabling Restore Points on (C:)"
    }
    
    process {
        $logger.informational("Enabling Restore Points on (C:)")
        Enable-ComputerRestore -Drive "C:\"
        if ($env:UserName -like "*Some NonDomain User*") {
            Write-Output "Creating Restore Point Called 'Beginning of Time'"
            $logger.informational("Creating Restore Point Called 'Beginning of Time'")
            Checkpoint-Computer -Description "Beginning of Time"
        }
        ELSE {
            Write-Output "Creating Restore Point Called 'Beginning of $env:UserName'"
            $logger.informational("Creating Restore Point Called 'Beginning of $env:UserName'")
            Checkpoint-Computer -Description "Beginning of $env:UserName"
        }
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}