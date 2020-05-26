function Get-StorageSense {
    <#
    .SYNOPSIS
        Retrieves Storage Sense options in Windows 10

    .DESCRIPTION
        Retrieves Storage Sense options in Windows 10 from the parent registry HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\StorageSense.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        None

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Get-StorageSense

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    Param (    

    )
    
    begin {
        # First block to add/change stuff in
        try {
            $ErrorActionPreference = 'SilentlyContinue'

            $parentRegistryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"

            $StorageSenseSchedule = @{
                1  = "Every Day"
                7  = "Every Week"
                30 = "Every Month" 
                0  = "During Low Free Disk Space"
            }
            
            $FileCleanupSchedule = @{
                0  = "Never"
                1  = "1 day"
                14 = "14 days"
                30 = "30 days"
                60 = "60 days"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    process {
    
        try {
            $storageSenseProperties = [ordered]@{
                Enabled                 = (Get-ItemPropertyValue -Path $parentRegistryKey -Name 01) -as [bool]
                RunStorageSense         = $StorageSenseSchedule[((Get-ItemPropertyValue -Path $parentRegistryKey -Name 2048))]
                RemoveAppFiles          = (Get-ItemPropertyValue -Path $parentRegistryKey -Name 04) -as [bool]
                RecycleBin              = (Get-ItemPropertyValue -Path $parentRegistryKey -Name 08) -as [bool]
                RecycleBinSchedule      = $FileCleanupSchedule[((Get-ItemPropertyValue -Path $parentRegistryKey -Name 256))]
                DownloadsFolder         = (Get-ItemPropertyValue -Path $parentRegistryKey -Name 32) -as [bool]
                DownloadsFolderSchedule = $FileCleanupSchedule[((Get-ItemPropertyValue -Path $parentRegistryKey -Name 512))]
                OneDrive                = (Get-ItemPropertyValue -Path "$parentRegistryKey\OneDrive*" -Name 02) -as [bool]
                OneDriveSchedule        = $FileCleanupSchedule[((Get-ItemPropertyValue -Path "$parentRegistryKey\OneDrive*" -Name 128))]
            }
            
            if (Get-ItemProperty -Path "$parentRegistryKey\SpaceHistory") {
                $storageSenseProperties.SpaceHistory = (Get-ItemProperty -Path "$parentRegistryKey\SpaceHistory").psbase.properties |
                Where-Object { $_.Name -match '\d{8}' } | ForEach-Object {
                    [pscustomobject]@{
                        Date           = [datetime]::ParseExact($_.Name, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
                        StorageCleaned = "$([math]::Round(($_.Value / 1GB * 1000000),2))GB"
                    }
                }
            }
            
            $storageSenseProperties        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }
    
    end {
        
    }
}
