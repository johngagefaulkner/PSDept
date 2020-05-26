function Get-LogInformation {
    <#
    .SYNOPSIS
        Parses the selected log file that is in supported formatting.

    .DESCRIPTION
        Parses the selected log file that is in supported formatting.

    .PARAMETER FilePath
        Log file to parse.

    .PARAMETER Filter
        Word to filter on.

    .PARAMETER Severity
        Severity to filter on. "Emergency","Alert","Critical","Error","Warning"

    .PARAMETER Count
        Count how many of each severity.

    .PARAMETER FullDetail
        Grab the full line of detail from the log.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Get-LogInformation -FilePath "C:\temp\log.log" -Count

    .EXAMPLE
        Get-LogInformation -FilePath "C:\temp\log.log" -Severity "Emergency","Alert"

    .EXAMPLE
        Get-LogInformation -FilePath "C:\temp\log.log" -FullDetail

    .EXAMPLE
        Get-LogInformation -FilePath "C:\temp\log.log" -Count -FullDetail

    .EXAMPLE
        Get-LogInformation -FilePath "C:\temp\log.log" -Severity "Emergency","Alert" -Count -FullDetail

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
                throw "File or folder does not exist"
            }
            if (-Not ($_ | Test-Path -PathType Leaf) ) {
                throw "The path argument must be a file. Folder paths are not allowed."
            }
            if ($_ -notmatch "(\.log)") {
                throw "The file specified in the path argument must be .log"
            }
            return $true 
        })]
        [string]$FilePath,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,

        [ValidateSet("Emergency","Alert","Critical","Error","Warning")]
        [array]$Severity = @("Emergency","Alert","Critical","Error","Warning"),

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [switch]$Count,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [switch]$FullDetail
    )
    
    begin {
        try {
            $log = Get-Content -Path $FilePath

            $hash = @{
                Emergency = $log | Select-String -SimpleMatch "[Emergency]"
                Alert = $log | Select-String -SimpleMatch "[Alert]"
                Critical = $log | Select-String -SimpleMatch "[Critical]"
                Error = $log | Select-String -SimpleMatch "[Error]"
                Warning = $log | Select-String -SimpleMatch "[Warning]"
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    process {
        try {
            if (!([string]::IsNullOrWhiteSpace($Filter))) {
                $log | Select-String -SimpleMatch $Filter
            }

            if ($FullDetail) {
                foreach ($level in $Severity) {
                    $hash[$level]
                }
            }

           if ($Count) {
                $severityCounts = [PSCustomObject]@{
                    Emergency   = ($hash["Emergency"]).count
                    Alert       = ($hash["Alert"]).count
                    Critical    = ($hash["Critical"]).count
                    Error       = ($hash["Error"]).count
                    Warning     = ($hash["Warning"]).count
                }
                $severityCounts
           }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end { 
        
    }
}