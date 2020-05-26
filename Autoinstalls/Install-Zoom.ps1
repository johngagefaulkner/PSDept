function Install-Zoom {
    <#
        .SYNOPSIS
            Installer script to install programs
        .DESCRIPTION
            Installer script to install programs
            	1. Validate the given config files path
                2. Take input for process names to kill, name of program, destination, and excluded items to not search for or download
                3. Start script logging
                4. Import path
                5. Figure out if msi or exe provider
                6. Grab nearest domain
                7. Test if the mutex, install availability, is open
                8. Add a wait condition of up to 600 seconds for the mutex
                9. Create download folder path
                10. Clear any old logs pertaining to the chosen install
                11. Copy down via robocopy the program and keep a log
                12. Check exit code of the copy to make sure it went alright
                13. Do any pre-install work
                14. Grab the current directory of copied program and grab latest item
                15. Build the install arguments
                16. Try to install the program and let you know the exit code and if any errors and log the install
                17. Do any post-install work
                18. Remove download folder
                19. End logging for script
        .PARAMETER Path
            Accepts a single Json file in array format
        .PARAMETER Name
            Name of the Program you wish to find in the Json File
        .PARAMETER Process
            Process name that you are going to kill
        .PARAMETER Destination
           Destination that you wish to download the files to
        .PARAMETER ExcludedItems
           Exclusion list for to keep from copying the listed files or folders or directories
        .PARAMETER LogPath
            Path of the logfile you want it to log to. Default is C:\Temp.
        .PARAMETER Clean
            Switch to forcfully clean the downloaded files, even if there was an error during install
        .INPUTS
            Json and String based items
        .OUTPUTS
            Description of objects that are output by the script.
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -Name FakeProgramListed
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -Process Chrome
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -Destination "$home\desktop"
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -ExcludedItems "Somefolder","File"
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -LogPath C:\Temp\FakeProgramListed
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -Clean
        .EXAMPLE
            Install-SoftwareTemplate -Path \\Server\Path\Here\Json.Json -Name FakeProgramListed -Process Chrome -Destination "$home\desktop" -ExcludedItems "Somefolder","File" -LogPath C:\Temp\FakeProgramListed -Clean
        .LINK
            https://github.com/kewlx/Auto_Installs/blob/master/README.md
        .NOTES
            None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
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

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Name = "Zoom",

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Process = "zoom meetings",

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Destination = "$home\Downloads",

        [Parameter(Mandatory = $false)]
        [String[]]$ExcludedItems = @("PKG","Sip Logging Zoom",""),

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "C:\Temp\Zoom",
        
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Switch]$Clean

    )
    
    begin {
        # Add Logging block
        try {
            if (!("PSLogger" -as [type])) {
                $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
                ."\\Server\Path\Here\Logging.ps1"
                $logger = [PSLogger]::new($LogPath, $callingScript)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        # First block to add/change stuff in
        try {       
            
            Function Grant-Admin {
                If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
                    $logger.Informational("PowerShell is not running as administrator. Attemping to restart in administrator mode.")
                    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -Verb RunAs
                    Exit
                }
            }
            Grant-Admin

            $logger.Informational("Importing $(Split-Path $PSBoundParameters.Path -Leaf)")
            $application = Get-Content $Path | ConvertFrom-Json
            
            if ($null -eq $application.Program.$Name.Source) {
                $errorInfo = @{
                    RecommendedAction = "Fix the name parameter within the current script [$(($MyInvocation.MyCommand.Name) -split ('.ps1'))] or fix the called json file"
                    Category          = 'ObjectNotFound'
                }
                $logger.informational("Listed program name [$Name] does not exist within the Json config file.")
                Write-Error "Listed program name [$Name] does not exist within the Json config file." @errorInfo
            }
            else {
                $downloadPath = "$Destination\$(Split-Path -Path $application.Program.$Name.Source -Leaf)"
            }

            if ($application.Program.$Name.filepath -contains 'msiexec.exe') {
                $extension = "msi"
            }
            else {
                $extension = "exe"
            }
    
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
            
            function Test-IsMutexAvailable {
                try {
                    $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
                    $Mutex.Dispose();
                    $logger.Informational("Mutex unavailable")
                    return $false
                }
                catch {
                    $logger.Informational("Mutex available")
                    return $true
                }
            }
    
            function Wait-Condition {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory)]
                    [ValidateNotNullOrEmpty()]
                    [scriptblock]$Condition,
            
                    [Parameter()]
                    [ValidateNotNullOrEmpty()]
                    [int]$CheckEvery = 30,
            
                    [Parameter()]
                    [ValidateNotNullOrEmpty()]
                    [int]$Timeout = 600
                )
            
                $ErrorActionPreference = 'Stop'
            
                try {
                    # Start the timer
                    $timer = [Diagnostics.Stopwatch]::StartNew()
            
                    # Keep in the loop while the item is false
                    Write-Verbose -Message "Waiting for condition..."
                    while (-not (& $Condition)) {
                        $logger.informational("Waiting for condition... $Condition")
                        Write-Verbose -Message "Waiting for condition..."
                        # If the timer has waited greater than or equal to the timeout, throw an exception exiting the loop
                        if ($timer.Elapsed.TotalSeconds -ge $Timeout) {
                            $logger.error("Timeout exceeded. Giving up... $Condition")
                            throw "Timeout exceeded. Giving up..."
                        }
                        # Stop the loop every $CheckEvery seconds
                        Start-Sleep -Seconds $CheckEvery
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                finally {
                    $timer.Stop()
                }
            }
    
            $EndTailArgs = @{
                Wait          = $True
                NoNewWindow   = $True
                ErrorAction   = "Stop"
                ErrorVariable = "+InstallingSoftware"
                PassThru      = $True
            }
    
            $RoboExitCodes = @{
                0  = "No files were copied. No failure was encountered. No files were mismatched. The files already exist in the destination directory; therefore, the copy operation was skipped."
                1  = "All files were copied successfully. Log File Location: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                2  = "There are some additional files in the destination directory that are not present in the source directory. No files were copied. Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                3  = "Some files were copied. Additional files were present. No failure was encountered. Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                4  = "Some Mismatched files or directories were detected. Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                5  = "Some files were copied. Some files were mismatched. No failure was encountered. Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                6  = "Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory.`
                Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                7  = "Files were copied, a file mismatch was present, and additional files were present.`
                Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                8  = "Some files or directories could not be copied. (copy errors occurred and the retry limit was exceeded). Check out these errors further. Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                16 = "Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories.`
                Check Log File: $LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
            }
            
            # Folder Creation
            foreach ($folderLocation in $LogPath, $downloadPath) {
                if (!(Test-Path -path $folderLocation)) {
                    [void](New-Item -path $folderLocation -ItemType Directory -Force -ErrorAction Stop -ErrorVariable +InstallingSoftware)
                }
            }
    
            # Clear Old Logs
            $logger.informational("Checking for old logs past 7 days...")
            $oldLogs = (Get-ChildItem "$LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)*.log").Where{ $_.LastWriteTime -LT (Get-Date).AddDays(-7) } 
            if (($oldLogs).count -ge 1) {
                $logger.warning("Removing Old log $($oldLogs.BaseName) ...")
                $oldLogs | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +InstallingSoftware
            }
    
            Wait-Condition -condition { Test-IsMutexAvailable } -CheckEvery 10
    
            if (!(Get-Variable -Name nearestDomain -ErrorAction SilentlyContinue)) {
                $nearestDomain = (Get-NearestDomain -Path "\\Server\Path\Here\Settings\JSON\DCList.json")
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    process {
    
        try {
            # Stop the processes
            $logger.informational("Attemping to stop process [$Process] ")
            (Get-Process).Where{ $_.Processname -match "$Process" } | Stop-Process -Force -ErrorAction SilentlyContinue -ErrorVariable +InstallingSoftware
 
            # Copy Files Locally to Stave Off Locked Files
            $logger.informational("Copying $Name...")
            Write-Output "Copying $Name..."
 
            $robocopyArgs = @{
                FilePath     = 'robocopy.exe'
                ArgumentList = @(
                    "\\$nearestDomain$($application.Program.$Name.Source)"
                    "$Destination\$(Split-Path -Path $application.Program.$Name.Source -Leaf)"
                    "/XD $ExcludedItems"
                    "/E"
                    "/R:5"
                    "/W:5"
                    "/LOG:$LogPath\$(Split-Path -Path $application.Program.$Name.Source -Leaf)-FileCopy.log"
                    "/TEE"
                )
            }
            $copy = Start-Process @robocopyArgs @EndTailArgs
 
            $RoboExitCodes[$copy.ExitCode]
            if ($copy.ExitCode -gt 7) {
                $logger.warning("Robocopy exit code indicates an issue with copying [RoboCopy ExitCode]:[$($copy.ExitCode)] $($RoboExitCodes[$copy.ExitCode])")
                Write-Output "Robocopy exit code indicates an issue with copying [RoboCopy ExitCode]:[$($copy.ExitCode)]"
                Start-Sleep -Seconds 7
                Exit
            }    
 
            # pre Setup software checks of changes here
            $Cleanup = Start-Process -FilePath "$downloadPath\settings\CleanZoom.exe" -ArgumentList /keepdata @EndTailArgs
 
            #######################################

            $latestSoftware = Get-ChildItem -path "$downloadPath\$extension\*.$extension" -Exclude $ExcludedItems -Recurse

            
            foreach ($Software in $latestSoftware) {
                $logger.informational("Starting software install for $Software...")
                Write-Output "Starting software install for $Software..."

                if ($Software.name -like "Zoom*Outlook*Plugin*"){
                    $Name = "Zoom Outlook Plugin"
                } else {
                    $Name = "Zoom"
                }

                if ($extension -contains 'msi') {
                    $app = $Software.FullName
                }
                else {
                    $filePath = $Software.FullName
                }

                $installerArgs = @{
                    FilePath     = $ExecutionContext.InvokeCommand.ExpandString($($application.Program.$Name.filepath))
                    ArgumentList = @(
                        $ExecutionContext.InvokeCommand.ExpandString($application.Program.$Name.argumentlist)
                    )
                }
                 
                $install = Start-Process @installerArgs @EndTailArgs
                switch ($install.ExitCode) {
                    ( { $PSItem -eq 0 }) { 
                        $logger.informational("$Name has Installed Successfully")
                        Write-Output "$Name has Installed Successfully" 
                        $Clean = $true
                        break
                    }
                    ( { $PSItem -eq 1641 }) {
                        $logger.informational("[LastExitCode]:$($install.ExitCode) - The requested operation completed successfully. The system will be restarted so the changes can take effect")
                        Write-Output "[LastExitCode]:$($install.ExitCode) - The requested operation completed successfully. The system will be restarted so the changes can take effect"
                        $Clean = $true
                        break
                    }
                    ( { $PSItem -eq 3010 }) {
                        $logger.informational("[LastExitCode]:$($install.ExitCode) - The requested operation is successful. Changes will not be effective until the system is rebooted")
                        Write-Output "[LastExitCode]:$($install.ExitCode) - The requested operation is successful. Changes will not be effective until the system is rebooted"
                        $Clean = $true
                        break
                    }
                    Default { 
                        $logger.error("[LastExitCode]:$($install.ExitCode) - $([ComponentModel.Win32Exception] $install.ExitCode)")
                        Write-Error -Message "[LastExitCode]:$($install.ExitCode) - $([ComponentModel.Win32Exception] $install.ExitCode)" 
                    }
                }

            }

            # post-Setup software checks of changes here
            regedit /s "$downloadPath\settings\ZoomOutlookAdd-in.reg"
            Start-Process "C:\Program Files (x86)\Zoom\bin\Zoom.exe"

            #######################################


        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        # Folder Cleanup
        if ($Clean){
            $logger.informational("Removing downloaded files and folders")
            Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +InstallingSoftware    
        }
        
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        $logger.Remove()
        
    }
}
Install-Zoom -Path "\\Server\Path\Here\Settings\JSON\Applications.json"