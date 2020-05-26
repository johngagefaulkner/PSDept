function Uninstall-LenovoPrograms {
    [CmdletBinding()]
    param (
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
        "-----------------------------------------------------"
        # Removes software if active on machine
        Write-Warning "Checking For Unwanted Programs..."
        $logger.informational("Checking For Unwanted Programs...")
        $softwarePaths = @(
            @{Output = "REACHit" ; Path = "C:\Program Files (x86)\REACHit" ; Uninstall = "MsiExec.exe /X '{4532E4C5-C84D-4040-A044-ECFCC5C6995B}' /q" },
            @{Output = "SHAREit" ; Path = "C:\Program Files (x86)\SHAREit Technologies\SHAREit" ; Uninstall = "Start-Process 'C:\Program Files (x86)\SHAREit Technologies\SHAREit\unins000.exe' /verysilent -Wait" },
            @{Output = "Connect2" ; Path = "C:\Program Files (x86)\Lenovo\Connect2" ; Uninstall = "Start-Process 'C:\Program Files (x86)\Lenovo\Connect2\unins000.exe' /verysilent -Wait" },
            @{Output = "Writeit" ; Path = "C:\Program Files (x86)\Lenovo\WRITEit" ; Uninstall = "MsiExec.exe /X '{31F6869C-2A11-4F78-962F-71CB9109B804}' /q" },
            @{Output = "Thinkvantage Password Manager" ; Path = "C:\Program Files (x86)\Lenovo\Password Manager" ; Uninstall = "MsiExec.exe /X '{70EE2BAA-F82A-4B8A-950E-649EFD64D5B9}' /q" },
            @{Output = "AutoScroll" ; Path = "C:\DRIVERS\AutoScroll" ; Uninstall = "C:\DRIVERS\AutoScroll\uuninst.bat -ErrorAction SilentlyContinue" }
        )
    }
    
    process {
        foreach ($softwarePath in $softwarePaths) {
            try {
                if (Test-Path -path $softwarePath.Path) {
                    Write-Output "$($softwarePath.Output) is uninstalling"
                    $logger.informational("$($softwarePath.Output) is uninstalling")
                    Invoke-Expression -Command "$($softwarePath.Uninstall)"
                }
            }
            catch {
                $logger.informational("$_.Exception.Message")
                Write-Host "$_.Exception.Message" -ForegroundColor Red
            }
        }

        Write-Output "Checking For Old AutoScroll Utility Files "
        $autoScrollFiles = "C:\DRIVERS\WIN\AUTOSCRL", "C:\DRIVERS\AutoScroll", "C:\Program Files\Lenovo\VIRTSCRL"
        foreach ($autoScrollFile in $autoScrollFiles) {
            If (Test-Path -Path $autoScrollFile) {
                Write-Output "$autoScrollFile Exists and will be deleted"
                Remove-Item -path $autoScrollFile -Recurse -Force
                $logger.informational("$autoScrollFile Exists and will be deleted")
            }
        }
    }
    
    end {
        Write-Verbose -Message "Finished Checking for Unwanted Programs"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}