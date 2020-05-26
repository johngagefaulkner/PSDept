function Resolve-BCDEdit {
    <#
    .SYNOPSIS
        Backup and cleanup

    .DESCRIPTION
        A longer description.

    .PARAMETER Description
        Description of each of the parameters.
        Note:
        To make it easier to keep the comments synchronized with changes to the parameters,
        the preferred location for parameter documentation comments is not here,
        but within the param block, directly above each parameter.

    .PARAMETER ExportBCDPath
        Export BCD to path.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Resolve-BCDEdit

    .EXAMPLE
        Resolve-BCDEdit -Description "somebusiness"

    .EXAMPLE
        Resolve-BCDEdit -ExportBCDPath "C:\bcd_backup.bcd"

    .EXAMPLE
        Resolve-BCDEdit -Description "somebusiness" -ExportBCDPath "C:\bcd_backup.bcd"

    .LINK
        Links to further documentation.

    .NOTES
        create test BCD using bcdedit /copy {current} /d "test"

    #>

    [CmdletBinding()]
    param (       
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [String]$Description,

        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$ExportBCDPath,

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

        $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
        $Description = "$Description-$winProductName"
        
        Write-Warning -Message "Resolving BCDEdit objects...Please be patient as this is an important task"
        # Create Backup
        function Export-CurrentBCDSettings {
            if (test-path -Path $exportBCDPath) {
                Remove-Item -Path $exportBCDPath -Force -ErrorAction SilentlyContinue
            }
            $logger.informational("Exporting Current BCDEdit Settings...")
            Write-Verbose -Message "Exporting Current BCDEdit Settings..."
            bcdedit /export "$exportBCDPath"
        }

        function Initialize-BCDOutputList {
            param (
                $Script:entries = ([System.Collections.Generic.List[pscustomobject]]::new()),
                $count = 0
            )
            do {
                Start-Sleep -Milliseconds 1700
                $count ++
                if($count -eq "2" -or "4"){
                   Export-CurrentBCDSettings
                }
            } until ((test-path -Path $exportBCDPath) -or ($count -eq "5"))

            if (!(test-path -Path $exportBCDPath)) {
                $logger.error("Current BCDEdit Settings where unable to backup properly. Please manually back them up. ")
                throw "Current BCDEdit Settings where unable to backup properly. Please manually back them up. "
            }
            # IMPORTANT: bcdedit /enum requires an ELEVATED session.
            # Initialize the output list.
            Write-Verbose -Message "Building BCDEdit Custom Object..."
            $bcdOutput = (bcdedit /enum) -join "`n" # collect bcdedit's output as a *single* string
            # Parse bcdedit's output.
            ($bcdOutput -split '(?m)^(.+\n-)-+\n' -ne '').ForEach( {
                if ($_.EndsWith("`n-")) {
                    # entry header 
                    $entries.Add([pscustomobject] @{ Name = ($_ -split '\n')[0]; Properties = [ordered] @{ } })
                }
                else {
                    # block of property-value lines
                    ($_ -split '\n' -ne '').ForEach( {
                            $propAndVal = $_ -split '\s+', 2 # split line into property name and value
                            if ($propAndVal[0] -ne '') {
                                # [start of] new property; initialize list of values
                                $currProp = $propAndVal[0]
                                $entries[-1].Properties[$currProp] = [System.Collections.Generic.List[string]]::new()
                            }
                            $entries[-1].Properties[$currProp].Add($propAndVal[1]) # add the value
                        })
                }
            })
        }

        function Remove-NonCurrentEntries {
            param (
                $winBootLoaders = ($entries.where( { $_.name -like "*Windows Boot Loader*" })),
                $Script:current = $entries.where( { $_.name -like "*Windows Boot Manager*" }).properties.default
            )
            Write-Verbose -Message "Removing Non-Current BCDEdit Boot Loader Objects..."
            foreach ($winBootLoader in $winBootLoaders) {
                if ($winBootLoader.properties.identifier -ne "$($current)") {
                    Write-output "$($winBootLoader.properties.identifier) is being removed"
                    $logger.notification("$($winBootLoader.properties.identifier) is being removed")
                    bcdedit /displayorder "$($winBootLoader.properties.identifier)" /remove
                    #bcdedit /delete "$($winBootLoader.properties.identifier)"
                }
            }    
        }
    }
    
    process {
        Export-CurrentBCDSettings

        Initialize-BCDOutputList

        # Output a quick visualization of the resulting list via Format-Custom
        #$entries | Format-Custom

        <#foreach ($entry in $entries) { 
            # Get the name.
            $name = $entry.Name
            # Get a specific property's value.
            $prop = 'device'
            $val = $entry.Properties[$prop] # $val is a *list*; e.g., use $val[0] to get the 1st item
            $val
        }#>

        if (($entries).count -gt 2) {
            Remove-NonCurrentEntries
        }
        # Rename {Current} description
        $logger.informational("Renaming {Current} description...")
        bcdedit /set "$current" description  "$description"
    }
    
    end {
        Write-Verbose -Message "Configuration of BCDEdit is Complete"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")        
    }
}