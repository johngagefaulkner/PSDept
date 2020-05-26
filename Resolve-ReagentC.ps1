function Resolve-ReagentC {
    <#
    .SYNOPSIS
        Re-enable windows recovery and clear old recovery partitions.

    .DESCRIPTION
        Re-enable windows recovery and clear old recovery partitions.

    .PARAMETER FirstParameter
        Description of each of the parameters.
        Note:
        To make it easier to keep the comments synchronized with changes to the parameters,
        the preferred location for parameter documentation comments is not here,
        but within the param block, directly above each parameter.

    .PARAMETER SecondParameter
        Description of each of the parameters.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Resolve-ReagentC

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param(
        $Partitions = (Get-Partition -DiskNumber 0 | Where-Object {$_.type -match "Recovery"})
    )
    begin {
        $ErrorActionPreference = "SilentlyContinue"
        $logger.warning("Checking Windows Recovery Environment...")
        Write-Warning -Message "Checking Windows Recovery Environment..."

        $env:SystemDirectory = [Environment]::SystemDirectory
        $xml = "$env:SystemDirectory\Recovery\ReAgent.xml"
        $analyzeReagentc = Invoke-Expression "$env:SystemDirectory\ReagentC.exe /info"   
        $analyzeReagentcEnabled = "$AnalyzeReagentC" -Match [regex]::new("Enabled")
        $analyzeReagentcDisabled = "$AnalyzeReagentC" -Match [regex]::new("Disabled")
    }
    process {
        if ($analyzeReagentcEnabled) {
            $logger.informational("Windows RE Status: Enabled")
            Write-Host "Windows RE Status: Enabled" -ForegroundColor Green
        }
        elseif ($analyzeReagentcDisabled) {
            try {
                Write-Verbose -Message "Enabling Windows Recovery Environment" -Verbose
                if (test-path -Path $xml) {
                    $logger.warning("Removing $xml")
                    Remove-Item -Path $xml
                }
                $enableWinRE = Invoke-Expression "$env:SystemDirectory\ReagentC.exe /enable" 
            }
            catch {
                $logger.Error("$PSitem")
                $PSCmdlet.ThrowTerminatingError($PSitem)
            }
        }
        else {
            $logger.warning("Unknown Windows RE Status")
            Write-Host "Unknown Windows RE Status" -ForegroundColor Yellow
        }

        try {
            if ($Partitions.count -gt 1) {
                [string]$recoveryPartition = $analyzeReagentc | select-string -pattern "partition"
                if(!([string]::IsNullOrWhiteSpace($recoveryPartition))){
                    if($recoveryPartition -match '(partition+\d)') {
                        $logger.informational("$($matches[0]) is the current recovery partition, removing non-used recovery partition")
                        Write-output "$($matches[0]) is the current recovery partition, removing non-used recovery partition"
                        if($matches[0] -match'(\d)') {
                            $Partitions | Where-Object {$_.PartitionNumber -notcontains "$($matches[0])"} | Remove-Partition
                            $logger.informational("Removed non-used recovery partition")
                        }
                    }                
                }                
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    end {
        "---------------------------------------"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}      
Resolve-ReagentC
