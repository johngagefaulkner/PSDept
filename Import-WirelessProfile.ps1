function Import-WirelessProfile {
    <#
    .SYNOPSIS
        Import a wireless profile.

    .DESCRIPTION
        Check if the current machine is a laptop, enable wifi adapter, Check adapter status,
        import wireless profile.

    .PARAMETER Path
        Accepts a single xml file.

    .PARAMETER Pattern
        The name of the wireless profile you want to check for.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Import-WirelessProfile -Path "\\Server\path\Wi-Fi 5-Wireless.xml"
        
    .EXAMPLE
        Import-WirelessProfile -Path "\\Server\path\Wi-Fi 5-Wireless.xml" -pattern "Wireless"

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
        [string]$Pattern,

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

        $CompConfig = Get-CimInstance -ClassName 'Win32_ComputerSystem' -Property PCSystemType
        $computerType = Switch ($CompConfig.PCSystemType) {
            1 { "Desktop"; break }
            2 { "Mobile/Laptop"; break }
            3 { "Workstation"; break }
            4 { "Enterprise Server"; break }
            default { "Not a known Product Type" }
        }

        $file = $(Split-Path -Path $path -Leaf)

        if ($computerType -eq "Mobile/Laptop") {
            $logger.informational("Enabling Wifi Adapter")
            (Get-NetAdapter).where( { ($_.name -like "wi-fi*") -or ($_.name -like "*Wireless*") }) | Enable-NetAdapter    
        }
    }
    
    process {
        try {
            if (!($env:UserName -like "*Some NonDomain User*") -and $computerType -eq "Mobile/Laptop") {
                $wifiAdapter = Get-NetAdapter | Where-Object { $_.name -like "Wi-Fi*" -or $_.name -like "*Wireless*" }
                if ($wifiAdapter) {
                    Write-Output "Wireless Adapter Status: $($wifiAdapter.status)"
                    $logger.informational("Wireless Adapter Status: $($wifiAdapter.status)")
                    $Wireless = netsh wlan show profiles | Select-String -Pattern $Pattern | ForEach-Object { ($_ -split ":")[-1].Trim() };

                    if (!($Wireless)) {
                        Write-Output "Adding [$file] Wifi Profile"
                        $logger.informational("Adding [$file] Wifi Profile")
                        netsh wlan add profile filename="$Path" "user=all"
                    }
                    else {
                        Write-Output "$Wireless Wifi Profile Already Exists"
                        $logger.informational("$Wireless Wifi Profile Already Exists")
                    }
                }
                else {
                    Write-Output "Wireless Adapter Status: Non-Existent"
                    $logger.informational("Wireless Adapter Status: Non-Existent")
                }
            }
        }
        catch {
            Write-Error -Message "Unable Load Wifi Profile"
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
