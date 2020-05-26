function Get-NearestDomain {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "File does not exist"
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw "The path argument must be a file. Folder paths are not allowed."
                }
                if ($_ -notmatch "(\.json)") {
                    throw "The file specified in the path argument must be .json"
                }
                return $true 
            })]
        [string]$Path,

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0, 9999)]
        [int]$LowestPing = 30,

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0, 10)]
        [int]$Count = 2
    )
    
    begin {
        
        $logger.Informational("Importing DC List Json")

        $DCs = Get-Content $Path | ConvertFrom-Json
    }
    
    process {
        $logger.Informational("Checking for closest DC")
        Write-Verbose -Message "Intializing Domain Check..."
        Foreach ($DC in $DCs) {
            $ping = (Test-Connection -ComputerName $DC -Count $Count -ea SilentlyContinue | Measure-Object -Property ResponseTime -Average)

            if ($ping.Average -lt $LowestPing -and $null -ne $ping.Average ) {
                $LowestPing = $ping.Average
                $nearestDomain = $DC

                if ($LowestPing -lt 13) {
                    break
                }
            }
        } 

    }
    
    end {
        Write-Verbose -Message "Finished Domain Check"
        $logger.Informational("Closest File Share or DC is $nearestDomain")
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        
        return $nearestDomain
    }
}