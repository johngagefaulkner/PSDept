function Get-ADSIBitLockerKeys {
    <#
    .SYNOPSIS
        Search AD and grab the bitlocker keys and create a report in one or more locations.

    .DESCRIPTION
        Search AD and grab the bitlocker keys and create a report.

    .PARAMETER SearchBase
        Searchbase you wish to start at.

    .PARAMETER OutFile
        Path to export the outfile

    .PARAMETER Clean
        Switch to clean up old reports that are 30 days old.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Get-ADSIBitLockerKeys -OutFile "\\server\path\here"

    .EXAMPLE
        Get-ADSIBitLockerKeys -OutFile "\\server\path\here" -Clean

    .EXAMPLE
        Get-ADSIBitLockerKeys -OutFile "\\server\path\here","$home\desktop\bitlockerkeys" -Clean

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SearchBase = "dc=NameHere,dc=root,dc=local",
        
        [Parameter(Mandatory = $false,
            Position = 1,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $OutFile = "$home\desktop\BitLocker-Reports",

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Switch] $Clean
    )
    
    begin {
        $Properties = @(
            'Name',
            'OperatingSystem',
            'DistinguishedName'
        )
        
        $BitLockerReportTimer = [Diagnostics.Stopwatch]::StartNew()
 
        $BackupDate = (Get-Date).ToString('MM.dd.yyyy')

        if (!(Get-Module -ListAvailable -Name PSWriteHTML)) {
            Write-Output "Importing 'PSWriteHTML' Module for report exporting..."
            Install-Module -Name PSWriteHTML -AllowClobber -Force
        } 

        foreach ($location in $OutFile) {
            if (!(Test-Path -Path "$location")) {
                Write-Output "Creating $location..."
                [void](New-Item -path $location -ItemType directory -force)
            }
        }
      
    }
    
    process {
        Write-Output "Building BitLocker Data..."
        $ADComputerList = Get-ADComputer -Filter * -SearchBase $SearchBase -Properties $Properties | Sort-Object -Property $Properties
        $StoredData = Foreach ( $ADComputer in $ADComputerList ) { 
            $DN = $ADComputer.DistinguishedName
            $ADobjList = Get-ADObject -Filter { objectclass -eq 'msFVE-RecoveryInformation' } -SearchBase $DN -Properties 'msFVE-RecoveryPassword' #| Select-Object Name, msFVE-RecoveryPassword |
            if ( $ADObjList ) {
                Foreach ( $ADObj in $ADObjList ) {
                    [PSCustomObject]@{
                        Computer         = $ADComputer.Name
                        RecoveryPassword = $ADobj.'msFVE-RecoveryPassword'
                        Date             = Get-Date -Date ($ADobj.Name).Split('{')[0]
                        BitlockerKeyID   = (($ADobj.Name ).Split('{')[1]).TrimEnd('}')
                    }
                }
            }
        }    

        foreach ($location in $OutFile) {
            $StoredData | Out-HtmlView -FilePath "$location\Bitlocker_Keys-$BackupDate.html"
        }

        if ($Clean) {
            foreach ($location in $OutFile) {
                "Cleaning up these $location location..."
                Get-ChildItem –Path $location –Recurse | Where-Object { $_.CreationTime –lt (Get-Date).AddDays(-29) } | Remove-Item -Recurse -Force
            }
        }

    }
    
    end {
        "Script Runtime:$($BitLockerReportTimer.Elapsed.ToString())"
        Write-Output "Finished Gathering/Exporting BitLocker Report Data"
        $BitLockerReportTimer.stop()

        Start-Sleep 5
    }
}

Get-ADSIBitLockerKeys -OutFile "\\server\path\here\BitLocker-Reports"