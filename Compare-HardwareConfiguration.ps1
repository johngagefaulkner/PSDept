function Compare-HardwareConfiguration {
    <#
    .SYNOPSIS
        Hardware configuration comparison.

    .DESCRIPTION
        Hardware configuration comparison.

    .PARAMETER Path
        Accepts a single Json file in array format
        
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .PARAMETER Misconfiguration
        Switch to show current and needed hardware configurations
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Compare-HardwareConfiguration -Path \\Server\Path\Here\HardwareConfigs.json

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

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp",

        [switch]$Misconfiguration
    )
    
    begin {
        try {
            
            $logger.Notice("Starting $($MyInvocation.MyCommand) script")
            
            $logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")
            $hardwareConfig = Get-Content $Path | ConvertFrom-Json   
            
            $DiskUniqueId = (Get-Disk | Where-Object { ($_.isboot -Eq "true" -and $_.Bustype -ne "USB") } | Select-Object UniqueId)
    
            try{
                $searcher = [adsisearcher]"(samaccountname=$env:USERNAME)"
                $department = $searcher.FindOne().Properties.department
            } catch [System.Management.Automation.MethodInvocationException] {
                $department = $null
            } 
            
            # Gets RAM amount
            $physicalRAM = (Get-CimInstance -ClassName 'Win32_PhysicalMemory' |
                Measure-Object -Property capacity -Sum | ForEach-Object { [Math]::Round(($_.sum / 1GB), 2) })
    
            # Gets drive type
            $drives = Get-CimInstance -ClassName 'MSFT_PhysicalDisk' -Namespace 'root\Microsoft\Windows\Storage' | Where-Object { $_.Bustype -ne "7" } | Select-Object UniqueId, MediaType
            foreach ($drive in $drives) {
                if ($DiskUniqueId.UniqueId -like $drive.UniqueId ) {
                    $driveType = switch ($drive.MediaType) {
                        3 { "HDD"; break }
                        4 { "SSD"; break }
                        'SSD' { "SSD"; break }
                        default { "The Drive is not in this list" }
                    }
                }
            }
    
            # Gets device type
            $CompConfig = Get-CimInstance -ClassName 'Win32_ComputerSystem' -Property PCSystemType
            $computerType = Switch ($CompConfig.PCSystemType) {
                1 { "Desktop"; break }
                2 { "Mobile/Laptop"; break }
                3 { "Workstation"; break }
                4 { "Enterprise Server"; break }
                default { "Not a known Product Type" }
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    process {
        try {
            $logger.informational("Comparing Hardware Config...")
            if (!($null -eq $hardwareConfig.$department)) {
                $config = $hardwareConfig.$department
            }
            else {
                $config = $hardwareConfig.Renaissance
            }
            $logger.informational("Using $($config.name) Configuration")
    
            if (!($computerType -like "Not a known*")) {
                if ($driveType -notmatch $config.$computerType.storage -or $physicalRAM -lt $config.$computerType.memory ) {
                    $logger.Alert("Computer $env:computername has a hardware misconfiguration.")
                    Write-Host "Computer $env:computername has a hardware misconfiguration." -ForegroundColor red
                    $Misconfiguration = $true
                }
            } else {
                $logger.warning("PCSystemType: $computerType, has no hardware configuration.")
                Write-Output "PCSystemType: $computerType, has no hardware configuration."
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        if ($Misconfiguration) {
            $hardwareMisconfiguration = [PSCustomObject]@{
                CurrentMemory  = $physicalRAM
                CurrentStorage = $driveType
                NeededMemory   = $config.$computerType.memory
                NeededStorage  = $config.$computerType.Storage
            }
            $logger.Alert("$hardwareMisconfiguration")
        }

        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        
        Return $hardwareMisconfiguration
    }
}
