function Set-DesktopShortcut {
    <#
    .SYNOPSIS
        A brief description of the function or script.

    .DESCRIPTION
        A longer description.

    .PARAMETER Path
        Accepts a single Json file in list format

    .PARAMETER Destination
        Destination folder to create shortcuts in.

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
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
            if (-Not ($_ | Test-Path) ) {
                throw "File does not exist"
            }
            if (-Not ($_ | Test-Path -PathType leaf) ) {
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
        [ValidateScript( {
            if (-Not ($_ | Test-Path) ) {
                throw "Folder does not exist"
            }
            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw "The path argument must be a folder. File paths are not allowed."
            }
            return $true 
        })]
        [string]$Destination
    )
    
    begin {
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        "-----------------------------------------------------"
        Write-Warning -Message "Creating Shortcuts..."
        
        if ($PSBoundParameters.ContainsKey("Path") ) {
            $logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")
            $shortcuts = Get-Content -Path $path | ConvertFrom-Json
        }   

        Get-Childitem -Path "C:\Users\Public\Desktop\*" -exclude $shortcuts.exclude | Remove-Item
        Get-Childitem -Path "$Destination\*" -Include $shortcuts.Include | Remove-Item        
        
    }
    
    process {
        # Goes through each shortcut and checks if it is exist, if not it creates it on the desktop.
        foreach ($Short in $Shortcuts.shortcuts) {
            if (Test-Path -path $Short.Target) {
                if ($null -eq $WshShell) {$WshShell = New-Object -comObject WScript.Shell}
                Write-Output "$Destination\$($Short.Link) is being created"
                $logger.Informational("$Destination\$($Short.Link) is being created")
                $Shortcut = $WshShell.CreateShortcut("$Destination\$($Short.Link)")
                $Shortcut.TargetPath = $Short.Target
                $Shortcut.Save() 
            }
        }
        
        # Release the Com Object
        [void][System.Runtime.Interopservices.Marshal]::FinalReleaseComObject($WshShell)
    }
    
    end {
        Write-Verbose -Message "Finished Creating Desktop Shortcuts"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
