function Copy-ChromeBookmarks {
    <#
    .SYNOPSIS
        Copies chromium bookmarks.

    .DESCRIPTION
        Copies chromium bookmarks.

    .PARAMETER Path
        Folder path to chromium bookmarks.

    .PARAMETER UserData
        Path to the userdata folder. Default is "$env:LOCALAPPDATA\Google\Chrome\User Data"

    .PARAMETER ExcludedItems
        An array of excluded items.

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
    Param(
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
        [string]$UserData = "$env:LOCALAPPDATA\Google\Chrome\User Data",

        [parameter(DontShow = $true)]
        [array]$ExcludedItems = @("*.reg", "*Bookmarks*", "*Favicons*")
    )
    
    begin {

        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
    }
    
    process {
        if (!(Test-Path -Path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")) {
            Write-Output "Google Chrome is not installed and cannot proceed with creating booksmarks."
            $logger.warning("Google Chrome is not installed and cannot proceed with creating booksmarks.")
        }
        elseif (!(Test-Path -Path "$UserData\Default")) {
            Write-Output "Setting Google Chrome Bookmarks"
            $logger.informational("Setting Google Chrome Bookmarks")
            Start-Process "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            Start-Sleep -s 5
            Get-Process -Name "chrome" | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -s 5
        }
        if (Test-Path -Path "$UserData\Default") {
            Copy-item -path "$Path\*" -Exclude $ExcludedItems[0], "*First Run*" -recurse -destination "$UserData\Default\"
            Copy-item -path "$Path\*" -Exclude $ExcludedItems -recurse -destination "$UserData\"
            $logger.informational("Copying Google Chrome Bookmarks and Favicons")    
        }
    }
    
    end {
        Write-Verbose -Message "Finished Setting Chrome Bookmarks"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
