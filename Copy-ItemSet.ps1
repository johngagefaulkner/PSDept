function Copy-ItemSet {
    <#
    .SYNOPSIS
        Copies the list of items needed for a build.

    .DESCRIPTION
        Copies the list of items needed for a build.

    .PARAMETER Path
        Accepts a single Json file in array format
        
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Copy-ItemSet -Path \\server\path\here\ItemSet.json

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
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
        [String]$LogPath = "C:\Temp"
    )
    
    begin {

        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath, $callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        $logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")
        $copiedItems = Get-Content $Path | ConvertFrom-Json   
    }
    
    process {
        try {
            foreach ($copiedItem in $copiedItems) {
                
                if (!(Test-Path -Path $ExecutionContext.InvokeCommand.ExpandString($copiedItem.Destination))) {
                    $logger.Informational("Creating directory $($ExecutionContext.InvokeCommand.ExpandString($copiedItem.Destination))")
                    [void](New-Item -path $ExecutionContext.InvokeCommand.ExpandString($copiedItem.Destination) -ItemType directory -force)
                }

                if (Test-Path -path $ExecutionContext.InvokeCommand.ExpandString($copiedItem.Path)) {
                    Write-Output "$($copiedItem.Output)"
                    Copy-Item -path $ExecutionContext.InvokeCommand.ExpandString($copiedItem.Path) -Exclude $($copiedItem.Exclude) -Recurse -Destination $ExecutionContext.InvokeCommand.ExpandString($copiedItem.Destination)
                    $logger.Informational("$($copiedItem.Output)")
                }    
            }

        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        Write-Verbose -Message "Finished Copying First Item Set"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}