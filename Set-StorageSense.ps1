function Set-StorageSense {
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
        Set-StorageSense -Enable -RunStorageSense 'Every Week' -RemoveAppFiles -RecycleBin '1 day' -DownloadsFolder '14 days' -OneDrive '1 day' -WhatIf
    .LINK
        Links to further documentation.
    .NOTES
        Detail on what the script does, if this is needed.
    #>
[cmdletbinding(SupportsShouldProcess = $true,DefaultParameterSetName = "StorageSense On")]
param(
    [Parameter(Mandatory = $false,ParameterSetName = "StorageSense On")]
    [switch]$Enable,

    [Parameter(Mandatory = $false,ParameterSetName = "StorageSense Off")]
    [switch]$Disable,

    [Parameter(Mandatory = $false,ParameterSetName = "StorageSense On")]
    [ValidateSet("Every Day","Every Week","Every Month","During Low Free Disk Space")]
    [string]$RunStorageSense,

    [Parameter(Mandatory = $false,ParameterSetName = "StorageSense On")]
    [Parameter(Mandatory = $false,ParameterSetName = "StorageSense Off")]
    [Parameter(Mandatory = $false,ParameterSetName = "Configure StorageSense")]
    [switch]$RemoveAppFiles,

    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense On")]
    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense Off")]
    [Parameter(Mandatory = $false, ParameterSetName = "Configure StorageSense")]
    [ValidateSet("Never","1 day","14 days","30 days","60 days")]
    [string]$RecycleBin,

    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense On")]
    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense Off")]
    [Parameter(Mandatory = $false, ParameterSetName = "Configure StorageSense")]
    [ValidateSet("Never","1 day","14 days","30 days","60 days")]
    [string]$DownloadsFolder,

    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense On")]
    [Parameter(Mandatory = $false, ParameterSetName = "StorageSense Off")]
    [Parameter(Mandatory = $false, ParameterSetName = "Configure StorageSense")]
    [ValidateSet("Never","1 day","14 days","30 days","60 days")]
    [string]$OneDrive
)
    
    begin {
        # Add Logging block
        try {
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

        # First block to add/change stuff in
        try {
            $parentRegistryKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"

            $StorageSenseSchedule = @{
                "Every Day" = 1
                "Every Week" = 7
                "Every Month" = 30
                "During Low Free Disk Space" = 0
            }
            
            $FileCleanupSchedule = @{
                "Never" = 0
                "1 day" = 1
                "14 days" = 14
                "30 days" = 30
                "60 days" = 60
            }

            $RegPath = [ordered]@{
                StorageSense = "01"
                RunStorageSense = "2048"
                RemoveAppFiles = "04"
                RecycleBin   = "08"
                RecycleBinSchedule = "256"
                DownloadsFolder = "32"
                DownloadsFolderSchedule = "512"
                OneDrive = "02"
                OneDriveSchedule = "128"
            }
    
    
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    process {
    
        try {

            # create parent key if not exist
            if (!(Test-Path -Path $parentRegistryKey)) {
                if ($PSCmdlet.ShouldProcess("$parentRegistryKey", "Creating registry key")) {
                    [void](New-Item -Path $parentRegistryKey -Force)
                }
            }
            
            $RegPath.GetEnumerator() | ForEach-Object{

                if ($psitem.key -like "OneDrive*" ) {
                    if ($PSBoundParameters.ContainsKey("OneDrive")) {
                        if (Get-ItemProperty -Path "$parentRegistryKey\OneDrive*" -Name $psitem.value -erroraction SilentlyContinue) {
                            if ($PSCmdlet.ShouldProcess("$parentRegistryKey\OneDrive* : $($psitem.value)", "Updating registry value")) {
                                [void](Set-ItemProperty -Path "$parentRegistryKey\OneDrive*" -Name $FileCleanupSchedule[($PSBoundParameters['OneDrive'])] -Force)
                            }
                        }
                    }
                } else {
                    if (!(Get-ItemProperty -Path $parentRegistryKey -Name $psitem.value -erroraction SilentlyContinue)) {
                        if ($PSCmdlet.ShouldProcess("$parentRegistryKey : $($psitem.value)", "Updating registry value")) {
                            [void](Set-ItemProperty -Path $parentRegistryKey -Name $psitem.value -Value 0  -Force)
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
        
    }
}