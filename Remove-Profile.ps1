function Remove-Profile {
    <#
    .SYNOPSIS
        Removes unwanted profiles from a json list

    .DESCRIPTION
        Removes unwanted profiles from a json list or string array. It will filter out the local profiles
        that match C:\Users\* and then remove the usernames from that list that do not match the current ones
        on the machine. Then it makes sure that the profile isn't special and not currently loaded.

    .PARAMETER Path
        Accepts a single Json file in list format

    .PARAMETER UserName
        Accepts an array of strings from 4-9 characters
    
    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Remove-Profiles -FilePath "C:\Users\user\Desktop\test.json"

    .EXAMPLE
        Remove-Profiles -Username $list

    .EXAMPLE
        Remove-Profiles -Username User1,User2,User3

    .EXAMPLE
        Get-ChildItem -Path "C:\Users\jscronce\desktop\test.json" | Remove-Profiles

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
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
            ValueFromPipelineByPropertyName = $true, 
            ParameterSetName = "Username")]
        [ValidateLength(4, 9)]
        [string[]]$UserName,

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
        
        Write-Verbose -Message "Building Profile List..."

        $logger.informational("Building Profile List...")
        $ProfileRemovalMembers = [System.Collections.Generic.List[String]]::new()
        $LocalProfiles = (Get-CimInstance -classname 'Win32_UserProfile' -Filter "LocalPath like 'C:\\Users\\%'" -Property LocalPath).LocalPath.replace("C:\Users\", "") 
       
        if ($PSBoundParameters.ContainsKey("Path") ) {
            $logger.Informational("Importing $(Split-Path $PSBoundParameters.Path -Leaf)")
            $Members = Get-Content $Path | ConvertFrom-Json   
        }
        else {
            $Members = $UserName
        }
    
        $logger.informational("Filtering Non-Existant Profiles...")
        foreach ($user in $Members) {
            if ($LocalProfiles -contains $user) {
                $ProfileRemovalMembers.Add($user)
            }
        }
    
    }
    
    process {
        foreach ($Member in $ProfileRemovalMembers) {
            if ($env:computername -like "*$Member*") {
                $logger.informational("$env:computername is a help desk member's computer, cannot clean")
                Write-Output "$env:computername is a help desk member's computer, cannot clean"
            }
            elseif ($env:username -like "*$Member*") {
                $logger.informational("$env:username is currently logged on, cannot clean")
                Write-Output "$env:username is currently logged on, cannot clean"
            }
            ELSE {
                $removeProfile = Get-CimInstance -ClassName 'Win32_UserProfile' |
                Where-Object { (!$_.Special -and $_.LocalPath -ne "C:\Users\Some NonDomain User" -and $_.LocalPath -ne "C:\Users\$env:username" -and
                        $_.LocalPath -like "*C:\Users\$Member*" -and $_.Loaded -eq $False) }

                if ($null -ne $removeProfile) {
                    Write-Verbose -Message "Clearing $Member from Profiles, as it is leftover from build..."
                    $logger.informational("Clearing $Member from Profiles, as it is leftover from build...")
                    $removeProfile | Remove-CimInstance
                }

                if (Test-Path -Path "C:\Users\$Member") {
                    $logger.informational("Clearing possible $Member leftovers in C:\Users...")
                    Write-Output "Clearing possible $Member leftovers in C:\Users..."
                    Get-ChildItem -Path "C:\Users\$Member" | Remove-Item -Recurse
                }
            }
        }
    }
    
    end {
        Write-Verbose -Message "Finished checking for leftover profiles."
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
