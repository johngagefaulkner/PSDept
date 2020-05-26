function Uninstall-WindowsBloatware {
    <#
    .SYNOPSIS
        A brief description of the function or script.

    .DESCRIPTION
        A longer description.

    .PARAMETER Path
        Accepts a single Json file in list format
        
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Example of how to run the script.

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
        $ProgressPreference = "SilentlyContinue"
        
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        if ($PSBoundParameters.Keys.Contains("Path") ) {
            $logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")
            $apps = Get-Content $Path | ConvertFrom-Json
        }  

    }
    
    process {
        Write-Verbose -Message "Initiating Windows 10 Bloatware Removal..."
        foreach ($app in $apps) {
            $package = Get-AppxPackage -Name $app -AllUsers
            try {
                if ($null -ne $package) {
                    $package | Remove-AppxPackage -ErrorAction SilentlyContinue
                    (Get-AppXProvisionedPackage -Online).Where( { $_.DisplayName -EQ $app }) | Remove-AppxProvisionedPackage -Online

                    $appPath = "$Env:LOCALAPPDATA\Packages\$app*"

                    $logger.Informational("Removing $appPath")
                    Remove-Item $appPath -Recurse -Force -ErrorAction 0
                }
            }
            catch {
                $logger.Informational("$_.Exception.Message the $app app had an issue uninstalling")
                Write-Host "$_.Exception.Message the $app app had an issue uninstalling" -ForegroundColor Red
            }
        }
    }
    end {
        $ProgressPreference = $OriginalPref
        Write-Verbose -Message "Finished Windows 10 Bloatware Removal"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
