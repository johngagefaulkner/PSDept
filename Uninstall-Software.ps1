<#
.SYNOPSIS
    Uninstall software
.DESCRIPTION
    Uninstall software of your choosing. The script will pull the uninstall and convert as need.
.EXAMPLE
    PS C:\> Uninstall-Software -software
    uses the name(s) defined to look for software and uninstall it
.INPUTS
    Software list
.OUTPUTS
    Host console will see a list of software names being uninstall as it happens.
.NOTES
    Version:        1.1
    Author:         Jon Cronce
    Creation Date:  05/24/2019
    Purpose/Change: Initial script development
#>
function Uninstall-Software {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,ParameterSetName='UninstallNames',
        HelpMessage="Enter one or more software names. Or use (gc C:\softwarelist.txt)")]
        [String]$Software,
        
        [parameter(DontShow = $true)]
        $Properties = @("DisplayName","UninstallString"),
        
        [parameter(mandatory=$false)]
        [switch]$CSV
    )
    
    begin {

        $32bit = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        $64bit = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

        $endTailArgs = @{
            Wait          = $True
            NoNewWindow   = $True
            ErrorAction   = "Stop"
            ErrorVariable = "+UninstallSoftware"
            PassThru      = $True
        }
        
        $qtVer = (Get-ChildItem -Path $32bit, $64bit | Get-ItemProperty) | Where-Object {$_.DisplayName -like "*$software*" }| Select-Object -Property $Properties
    }
    
    process {
        try {
            if ($CSV) {
                $qtVer | Sort-Object DisplayName | Export-Csv -Path "$home\desktop\uninstallInfo.csv" -NoTypeInformation
            } else {
                ForEach ($ver in $qtVer) {
                    If ($ver.UninstallString) {
                        $uninst = $ver.UninstallString
                        $uninst = $uninst -replace "/I", "/x "
                        $uninstall = Start-Process -FilePath cmd.exe -ArgumentList '/c', "$uninst /Q" @endTailArgs
                        
                        if ([int]$uninstall.lastexitcode -eq 0) {
                            Write-Output "LastExitCode: $($uninstall.ExitCode) - $Software has uninstalled properly"
                           
                        } else {
                            Write-Error -Message "LastExitCode: $($uninstall.ExitCode) - $Software has not uninstalled properly" -ErrorVariable +UninstallSoftware
                        }
                        
                    }
                }
                    
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        if ($null -ne $UninstallSoftware) {
           return $UninstallSoftware
        }
    }
}