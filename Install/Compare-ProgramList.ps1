function Compare-ProgramList {
    <#
    .SYNOPSIS
        Compares the list of applications to whats installed and outputs an object.
    .DESCRIPTION
        Compares the list of applications to whats installed based on department and outputs an object.
    .PARAMETER Path
        Accepts a single Json file in array format
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
    .INPUTS
        Description of objects that can be piped to the script.
    .OUTPUTS
        Description of objects that are output by the script.
    .EXAMPLE
        Compare-ProgramsList -Path "\\server\path\here\Applications.json"
    .LINK
        Links to further documentation.
    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
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

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "C:\Temp"
    )
    
    begin {
        try {
            
            if (!("PSLogger" -as [type])) {
                $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
                ."\\Server\Path\Here\Logging.ps1"
                $logger = [PSLogger]::new($logPath, $callingScript)
            }

            $logger.Notice("Starting $($MyInvocation.MyCommand) script")           
            $logger.Informational("Importing Application Configuration Json")

            $installationList = Get-Content -path $Path | ConvertFrom-Json

            try {
                $searcher = [adsisearcher]"(samaccountname=$env:USERNAME)"
                $department = $searcher.FindOne().Properties.department
                $logger.Informational("Department: $department")
            }
            catch [System.Management.Automation.MethodInvocationException] {
                $logger.Informational("Department does not exist in the Json. Defaulting to Default.")
                $department = $null
            } 

            if (!($null -eq $installationList.$department)) {
                $departmentPrograms = $installationList.department.$department
            }
            else {
                $departmentPrograms = $installationList.department.Default
            }

        } 
        catch [System.UnauthorizedAccessException] {
            $logger.Error("Unauthorized Access")
            throw "Unauthorized Access"
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    process {

        try {
            $information = foreach ($program in $departmentPrograms) {
                #$installed = Get-Package

                $localProgram = (Get-Package -name "*$program*" -ErrorAction SilentlyContinue)

                if ([string]::IsNullOrWhiteSpace($localProgram)) {
                    $Installed = $false                  
                }
                else {
                    $Installed = $true
                }
                
                if (!([string]::IsNullOrWhiteSpace($installationList.Program.$program))) {
                    $AutoInstallSupport = $true
                }
                else {
                    $AutoInstallSupport = $false
                }

                [PSCustomObject]@{
                    Name               = $program
                    Installed          = [bool]$Installed
                    AutoInstallSupport = [bool]$AutoInstallSupport
                }

            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        foreach ($info in $information){$logger.Informational("$info")}
        $information
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
