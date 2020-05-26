function Disable-Startups {
    <#
    .SYNOPSIS
        Disables the startup of a list of items

    .DESCRIPTION
        Checks all startup locations including registry for the programs startup and removes it

    .PARAMETER Path
        Accepts a single Json file in list format
        
    .PARAMETER DisableList
        Add multiple startup names to be searched for, and disabled.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Disable-Startups -Path \\server\path\here.json

    .EXAMPLE
        Disable-Startups -DisableList ciscovpn,blizzard,justsched

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding(DefaultParameterSetName = "Path")]
    Param(
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Path",
            Position = 0)]
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
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "DisableList")]
        [ValidateNotNullOrEmpty()]
        [string[]]$DisableList,

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
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

        $32bit = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        $32bitRunOnce = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        $64bit = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        $64bitRunOnce = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
        $currentLOU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        $currentLOURunOnce = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

        if ($PSBoundParameters.ContainsKey("Path") ) {
            $logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")
            $DisableList = Get-Content $Path | ConvertFrom-Json   
        }

        # HKU Hive has to be registered
        $logger.informational("Registering PSProvider:HKEY_USERS")
        New-PSDrive -PSProvider 'Registry' -Name 'HKU' -Root 'HKEY_USERS' | Out-Null

        # Grab startups
        $startups = Get-CimInstance "Win32_StartupCommand" | Select-Object Name, Location

        # Create list registry array
        $regStartList = Get-Item -path $32bit, $32bitRunOnce, $64bit, $64bitRunOnce, $currentLOU, $currentLOURunOnce |
        Where-Object { $_.ValueCount -ne 0 } | Select-Object property, name
    }
    process {
        foreach ($startUp in $startUps) {
            if ($startUp.name -in $disableList) {
                if ($startup.Location -like "*Startup*") {
                    $logger.informational("Disabling $($startUp.Name) from $($startup.Location)")
                    Write-Output "Disabling $($startUp.Name) from $($startup.Location)"
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$disablelist"
                }
                else {
                    # Format name to powershell standards
                    $number = ($startUp.location).IndexOf("\")
                    $location = ($startUp.location).Insert("$number", ":")

                    $logger.informational("Disabling $($startUp.Name) from $location")
                    Write-Output "Disabling $($startUp.Name) from $location"
                    Remove-ItemProperty -Path $location -Name "$($startUp.name)"
                }
            }
        }
        
        # Disables in items in registries
        foreach ($regName in $regStartList.name) {

            $regName = $regName.Replace("HKEY_LOCAL_MACHINE\", "HKLM:\").replace("HKEY_CURRENT_USER\", "HKCU:\").replace("HKEY_USER", "HKU:\")
            
            foreach ($disable in $disableList) {
                if (Get-ItemProperty -Path $regName -name $disable -ErrorAction SilentlyContinue) {
                    $logger.informational("Removing $disable from $regName")
                    Write-Output "Removing $disable from $regName"
                    Remove-ItemProperty -Path $regName -Name $disable
                }
            }

        }

    }
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
