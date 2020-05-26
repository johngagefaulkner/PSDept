function Import-PowerSetting {
    <#
    .SYNOPSIS
        Imports a power setting file.

    .DESCRIPTION
        Imports a power setting file. Validates the import and setting to active power scheme.
        Changes a registry location so as not to lose the ability to select the more granular settings later.

    .PARAMETER Path
        Accepts a single power setting file.

    .PARAMETER GUID
        Guid you wish to compare to. Default GUID is d718026f-979c-418f-a0b8-179a5abfe6ba.

    .PARAMETER PowerPlan
        Power plan name.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Import-PowerSetting -Path $latestPowerCfg -PowerPlan "renaissance"

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
            if ($_ -notmatch "(\.pow)") {
                throw "The file specified in the path argument must be .pow"
            }
            return $true 
        })]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidatePattern('([A-Za-z0-9]{8}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{12})')]
        [string]$GUID = "d718026f-979c-418f-a0b8-179a5abfe6ba",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]        
        [string]$PowerPlan = ("$_").toLower(),

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
        #get
        #Get-CimInstance -N "root\cimv2\power" -ClassName "win32_PowerPlan" | select ElementName, IsActive

        #import
        

        #set
        #$p = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High Performance'"
        #Invoke-CimMethod -InputObject $p -MethodName Activate

        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        Write-Output "Checking Power Configuration Settings..."        
        $perf = powercfg -l | ForEach-Object {if($_.toLower().contains($PowerPlan)) {$_.split()[3]}}
        $activePowerScheme = (powercfg -getactivescheme).split()[3]
    }
    
    process {        
        try {
            if ($activePowerScheme -match $GUID) { 
                Write-Output "'$PowerPlan' is already the active power plan"
                $logger.informational("'$PowerPlan' is already the active power plan")    
             } else {
                if($null -eq $perf) { 
                    Write-Output "Importing Power Configuration Settings..."
                    $logger.informational("Importing Power Configuration Settings...")
        
                    powercfg -import "$Path" $GUID
                    if ($? -ne $true) {
                        $logger.Error("$Path $GUID Failed to import properly")
                        Write-Host "$Path $GUID Failed to import properly" -ForegroundColor Red
                    }
                 }
                if ($activePowerScheme -ne $perf) { 
                    Write-Output "Setting Active Power Configuration..."
                    $logger.informational("Setting Active Power Configuration...")
                    
                    powercfg -setactive $GUID
                    if ($? -ne $true) {
                        $logger.Error("Power Configuration [$GUID] Failed to set properly")
                        Write-Host "Power Configuration [$GUID] Failed to set properly" -ForegroundColor Red
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
        # Re-enable all power settings to be visible
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CsEnabled" -Type DWord -Value 0

        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}