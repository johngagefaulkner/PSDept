function Import-DefaultAssociation {
    <#
    .SYNOPSIS
        Sets file default associations.

    .DESCRIPTION
        Sets file default associations.

    .PARAMETER Path
        Accepts a single xml file.

    .PARAMETER Destination
        Destination to copy the xml file.

    .PARAMETER DefaultDISMLocations
        Default dism exe locations. Defaults are "DISM.EXE","C:\WINDOWS\SYSNATIVE\DISM.EXE"

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Import-DefaultAssociation -Path "\\server\path\DefaultApps.xml"

    .EXAMPLE
        Import-DefaultAssociation -Path "\\server\path\DefaultApps.xml" -Destination "$home\desktop"

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
            if ($_ -notmatch "(\.xml)") {
                throw "The file specified in the path argument must be .xml"
            }
            return $true 
        })]
        [string]$Path,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination = "$home\desktop",

        [parameter(DontShow = $true)]
        $DefaultDISMLocations = @("DISM.EXE","C:\WINDOWS\SYSNATIVE\DISM.EXE"),

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

        $file = Split-Path -Path $path -Leaf
        if (!(test-path -Path "$Destination\$file")){
            $logger.Informational("Copying $Destination\$file to desktop...")
            Copy-Item -Path $Path -Destination "$Destination\$file"
        }

        Write-Verbose -Message "Building DISM Default Association Parameters..."
        $defaultArgs = @{
            FilePath      = "$($defaultDISMLocations[0])"
            ArgumentList  = @(
                "/Online" 
                "/Import-DefaultAppAssociations:$Destination\$file"
            )
            Wait          = $True
            NoNewWindow   = $True
            ErrorAction   = "Stop"
            ErrorVariable = "+DefaultApps"
            PassThru      = $True
        }
    }
    
    process {
        Write-Verbose -Message "Running DISM Default Association..."
        try {
            Write-Output "Running DISM Default Association..."
            $logger.Informational("Running DISM Default Association...")
            $Default = Start-Process @defaultArgs
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        Write-Verbose -Message "Finished DISM Default Association"
        if ($Default.ExitCode -eq 0) {
            $logger.Informational("[Default Apps exitcode]:$($Default.exitcode) Successful")
            Write-Output "[Default Apps exitcode]:$($Default.exitcode) Successful"
            Remove-Item -Path "$Destination\$file" -Force -ErrorAction SilentlyContinue
            $logger.Informational("Removing $Destination\$file")
        }
        else {
            $logger.Warning("[Default Apps exitcode]:$($Default.exitcode) Failed.")
            Write-warning -message "[Default Apps exitcode]:$($Default.exitcode) Failed."
            $logger.Informational("Please Run Manually $($defaultArgs.FilePath) $($defaultArgs.ArgumentList)")
            Write-Output "Please Run Manually $($defaultArgs.FilePath) $($defaultArgs.ArgumentList)"
        }
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
