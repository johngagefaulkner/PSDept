function Get-MacPartition {
    [CmdletBinding()]
    param (
        [string]$Path = "\\$nearestDomain\helpdesk\Saba\How to change password on a Mac.docx"
    )
    
    begin {
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        $partitionCheck = Get-Partition | Where-Object -FilterScript { ($_.Type -Eq "Unknown" -and $_.Size / 1GB -gt "100") } | Select-Object -ExpandProperty type
    }
    
    process {
        if ($partitionCheck -eq "Unknown") {
            $logger.Informational("$env:computername seems to be apart of a Mac build. Copying Mac password instructions")
            Write-Output "$env:computername seems to be apart of a Mac build. Copying Mac password instructions"
            Copy-Item -Path $Path -Destination "$home\desktop"
            $logger.Informational("Copying '$Path' to desktop ")
        }    
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
