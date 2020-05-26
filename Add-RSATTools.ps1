<#
.SYNOPSIS
    Adds "ActiveDirectory", "bitlocker", "wsus" RSAT tools to the computer.
.DESCRIPTION
    Turns off WSUS connection and adds the RSAT tools "ActiveDirectory", "bitlocker", "wsus".
    Then turns the WSUS connection back on.
.EXAMPLE
    PS C:\> .\Add-RSATTools
    Runs the function.
.INPUTS
    None
.OUTPUTS
    Outputs in green or red text if the option was installed properly.
.NOTES
    General notes
    Error 0x800f0954 happens, unless you turn off WSUS updates and restart the service
    Get-WindowsCapability -Online  to show all features

#>
function Add-RSATTools {
    <#
    .SYNOPSIS
        A brief description of the function or script.

    .DESCRIPTION
        A longer description.

    .PARAMETER FirstParameter
        Description of each of the parameters.
        Note:
        To make it easier to keep the comments synchronized with changes to the parameters,
        the preferred location for parameter documentation comments is not here,
        but within the param block, directly above each parameter.

    .PARAMETER SecondParameter
        Description of each of the parameters.

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
        [parameter(DontShow = $true)]
        $WSUSReg = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU\",
        [parameter(DontShow = $true)]
        $name = "UseWUServer",
        [parameter(DontShow = $true)]
        $ON = "1",
        [parameter(DontShow = $true)]
        $OFF = "0",
        [parameter(DontShow = $true)]
        $service = "wuauserv"

    )
    
    begin {
        # Array for Rsat tools
        $installTools = @(
            "ActiveDirectory",
            "bitlocker",
            "wsus"
        )
        $availableRSAT = Get-WindowsCapability -Name RSAT* -Online
    }
    
    process {
        # Turn off WSUS connection in Registry
        Set-ItemProperty -Path "$WSUSReg" -name "$name" -Type Dword -Value $OFF

        # Restart WSUS Service and Install Add-Ons
        Get-Service -Name $service | Restart-Service -Force
        foreach ($install in $installTools) {
            $availableRSAT |
                Where-Object {$_.Name -like "*$install*" } | Add-WindowsCapability -Online
        }

        # Turn on WSUS connection in Registry
        Set-ItemProperty -Path "$WSUSReg" -name "$name" -Type Dword -Value $ON

        # Restart WSUS Service
        Get-Service -Name $service | Restart-Service -Force
    }
    
    end {
        # Check installed items
        $installed = Get-WindowsCapability -Name RSAT* -Online | where-object {$_.state -like "installed"}
        foreach ($install in $installed) {
            Write-host "Installed $($install.displayname)" -ForegroundColor Green
        }
        Pause
    }
}
Add-RSATTools