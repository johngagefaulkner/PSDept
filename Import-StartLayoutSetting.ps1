function Import-StartLayoutSetting {
    <#
    .SYNOPSIS
        Import start layout settings file.

    .DESCRIPTION
        Import start layout settings file.

    .PARAMETER Path
        Accepts a single xml file.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Import-StartLayoutSetting -Path "\\server\path\taskbartest.xml"

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
    }
    
    process {
        if (($winProductName -like "*10 Pro*" -or $winProductName -like "*10 enterprise*") -and $env:username -like "Some NonDomain User*") {
            Write-Output "Importing Start Menu Layout..."
            $logger.informational("Importing Start Menu Layout...")
            Import-StartLayout -LayoutPath $Path -MountPath "C:\"
        }
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
