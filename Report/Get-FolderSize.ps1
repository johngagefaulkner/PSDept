function Get-FolderSize {
    <#
    .SYNOPSIS
        Reads the size of each item in a location and the total storage used. Then export these to a csv.

    .DESCRIPTION
        Reads the size of each item in a location and the total storage used. Then export these to a csv.

    .PARAMETER Path
        one or more paths to export a csv too

    .PARAMETER Recurse
        Recurse down into the folders for more granular information.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        CSV with file information.

    .EXAMPLE
        Get-FolderSize -Path "$home\downloads"
        Grab the file information in the downloads folder.

    .EXAMPLE
        Get-FolderSize -Path "$home\downloads","$home\desktop"
        Grab the file information in the downloads and desktop folder.

    .EXAMPLE
        Get-FolderSize -Path "$home\downloads" -Recurse
        Grab the file information in the downloads folder and recurse through them.

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage = "Enter a UNC path like \\server\share")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "$_ Path does not exist."
                }
                if ($_ -match "(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/))") {
                    throw "$_ The path specified in the argument must be a network share, file, or folder. URLs are not allowed."
                }
                return $true
            })]
        [string[]]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    begin {
        # Create a folder to hold everything
        if (!(Test-Path -Path "$home\desktop\ShareSizes")) {
            [void](New-Item -Path "$home\desktop\ShareSizes" -ItemType Directory)
        }
        function Format-HumanReadableByteSize {
            param (
                [parameter(ValueFromPipeline)]
                [ValidateNotNullorEmpty()]
                [double]$InputObject
            )

            # Handle this before we get NaN from trying to compute the logarithm of zero
            if ($InputObject -eq 0) {
                return "0 Bytes"
            }
            
            $magnitude = [math]::truncate([math]::log($InputObject, 1024))
            $normalized = $InputObject / [math]::pow(1024, $magnitude)
            
            $magnitudeName = switch ($magnitude) {
                0 { "Bytes"; Break }
                1 { "KB"; Break }
                2 { "MB"; Break }
                3 { "GB"; Break }
                4 { "TB"; Break }
                5 { "PB"; Break }
                Default { Throw "Byte value too big" }
            }
            
            "{0:n2} {1}" -f ($normalized, $magnitudeName)
        }    
    }
    
    process {
        foreach ($Share in $Path) {
            $totalSize = $null
            $sharename = $share.replace('\', '-').replace(':', '')
            $output = "$home\desktop\ShareSizes\$($sharename) Size Information.csv"

            if (test-path -path $output) {
                get-childitem -Path $output | Remove-Item -Force
            }

            Write-Verbose -Message "Building $share CSV"
            # Grab needed data
            $collection = Get-ChildItem -Path $Share -Recurse:$Recurse | Select-Object  fullname, name 

            $information = foreach ($folder in $collection) {
                # Get byte count of each item
                $bytecount = "{0:N2}" -f ((Get-ChildItem $folder.FullName -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum)
                # Keep track of total size for each share
                $totalSize = ([double]$bytecount + [double]$totalSize)
                # Current Folder size
                $size = ($bytecount | Format-HumanReadableByteSize)
                [PSCustomObject]@{
                    Name      = $folder.name
                    FullPath  = $folder.fullname
                    Size      = $size
                    TotalSize = ""
                }
            }

            $information | export-csv -Path $output -Append -NoTypeInformation

            # Export Total size for the share
            $totalSize = ($totalSize | Format-HumanReadableByteSize)
            [PSCustomObject]@{
                Name      = ""
                FullPath  = ""
                Size      = ""
                TotalSize = "$totalSize"
            } | export-csv -Path $output -Append -NoTypeInformation
        }
    }
    
    end {
        Write-Verbose -Message "Finished Building CSV(s)"
        #[System.gc]::gettotalmemory("forcefullcollection") /1MB
        [GC]::Collect()
    }
}