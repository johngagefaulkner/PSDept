#Start menu has to be imported before users are created for it to replicate through accounts properly
function Import-StartLayoutSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
        [ValidateScript( {
            if (-Not ($_ | Test-Path) ) {
                throw "File or folder does not exist"
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

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "C:\Temp",
        
        [parameter(DontShow = $true)]
        $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        $script:currentFunction = $MyInvocation.MyCommand
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
    }
    
    process {
        if (($winProductName -like "*10 Pro*" -or $winProductName -like "*10 enterprise*") -and $env:username -like "RLIUSER*") {
            Write-Output "Importing Start Menu Layout..."
            $logger.informational("Importing Start Menu Layout...")
            Import-StartLayout -LayoutPath $Path -MountPath "C:\"
        }
        elseif (!($env:username -like "RLIUSER*")) {
            $XML = Get-Content "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
            $XML | ForEach-Object { $_.Replace(' PinListPlacement="Replace"', '' ) } | Set-Content "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
            Start-Sleep -Milliseconds 1500
            Regedit /s "\\Server\Path\Here\Settings\Startlayout\Startlayout.reg"
        }
    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        $script:currentFunction = ""
    }
}
Import-StartLayoutSettings -Path "\\Server\Path\Here\Settings\Startlayout\TaskbarLayout.xml"
#Export-Startlayout -path "$home\desktop\defaultStartMenu.xml"