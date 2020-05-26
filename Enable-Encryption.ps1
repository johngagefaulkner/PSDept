using namespace System.Management.Automation.Host
function Enable-Encryption {
    <#
    .SYNOPSIS
        Encrypts the drive with bitlocker.

    .DESCRIPTION
        Checks and fixes the reagent file and WinRE.
        Checks compatibility between the tpm Version, firmware type and partiton style.
        If everything is working correctly or set properly then it will check to see if the computer is bitlocked and if not
        then it will prompt to bitlock and backup the key to AD and create a file on the first USB drive plugged into the computer.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .PARAMETER BackUpKey
        Only Creates a Backup Key

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Enable-Encryption

    .EXAMPLE
        Enable-Encryption -CheckCompatibility

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp",

        [Parameter(Mandatory=$false)]
        [switch]$CheckCompatibility
    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        
        if ($env:UserName -like "*Some NonDomain User*") {
            return Write-Warning -message "Logged in as $env:UserName, You cannot encrypt a drive on a non-AD account."   
        }
        $winProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
        $tpm = (Get-Tpm)
 
        $TPMInfo = [PSCustomObject]@{
            Version = ((Get-CimInstance -Classname "Win32_Tpm" -Namespace "root\cimv2\Security\MicrosoftTpm").SpecVersion).Split("{,}")[0]
            Present = $tpm.TpmPresent
            Ready   = $tpm.TpmReady
        }

        $BLV = Get-BitLockerVolume -MountPoint "C:"
        $BLVKeyProtector = $BLV.KeyProtector | Where-Object {$_.KeyProtectorType -like "recoverypassword"} | Select-Object -Last 1

        $date = (Get-Date -Format "MMddyyyy")

        # Checks the Partition type and warns you if its not GPT, for Bitlocker reasons
        $partitonStyleCheck = Get-Disk | Where-Object -FilterScript {$_.isboot -Eq "true"} | Select-Object -ExpandProperty partitionstyle

        # Checks if WinRE is enabled, if not, corrects it
        function Resolve-ReagentC {
            param(
                $partitions = (Get-Partition -DiskNumber 0 | Where-Object {$_.type -match "Recovery"})
            )
            begin {
                $ErrorActionPreference = "SilentlyContinue"
                $logger.informational("Checking Windows Recovery Environment...")
                Write-Warning -Message "Checking Windows Recovery Environment..."
        
                $env:SystemDirectory = [Environment]::SystemDirectory
                $xml = "$env:SystemDirectory\Recovery\ReAgent.xml"
                $analyzeReagentc = Invoke-Expression "$env:SystemDirectory\ReagentC.exe /info"   
                $analyzeReagentcEnabled = "$AnalyzeReagentC" -Match [regex]::new("Enabled")
                $analyzeReagentcDisabled = "$AnalyzeReagentC" -Match [regex]::new("Disabled")
            }
            process {
                if ($analyzeReagentcEnabled) {
                    $logger.informational("Windows RE Status: Enabled")
                    Write-Host "Windows RE Status: Enabled" -ForegroundColor Green
                }
                elseif ($analyzeReagentcDisabled) {
                    try {
                        Write-Verbose -Message "Enabling Windows Recovery Environment"
                        if (test-path -Path $xml) {
                            $logger.warning("Removing $xml")
                            Remove-Item -Path $xml
                        }
                        Invoke-Expression "$env:SystemDirectory\ReagentC.exe /enable" 
                    }
                    catch {
                        $logger.Error("$PSitem")
                        $PSCmdlet.ThrowTerminatingError($PSitem)
                    }
                }
                else {
                    $logger.warning("Unknown Windows RE Status")
                    Write-Host "Unknown Windows RE Status" -ForegroundColor Yellow
                }
        
                try {
                    if ($partitions.count -gt 1) {
                        [string]$recoveryPartition = $analyzeReagentc | select-string -pattern "partition"
                        if(!([string]::IsNullOrWhiteSpace($recoveryPartition))){
                            if($recoveryPartition -match '(partition+\d)') {
                                $logger.informational("$($matches[0]) is the current recovery partition, removing non-used recovery partition")
                                Write-output "$($matches[0]) is the current recovery partition, removing non-used recovery partition"
                                if($matches[0] -match'(\d)') {
                                    $partitions | Where-Object {$_.PartitionNumber -notcontains "$($matches[0])"} | Remove-Partition
                                    $logger.informational("Removed non-used recovery partition")
                                }
                            }                
                        }                
                    }
                }
                catch {
                    $logger.Error("$PSitem")
                    $PSCmdlet.ThrowTerminatingError($PSitem)
                }
        
            }
            end {
                
            }
        }      
        Resolve-ReagentC
        
        function Get-ADSystemInfo{
            # https://technet.microsoft.com/en-us/library/ee198776.aspx
                $properties = @(
                    'UserName',
                    'ComputerName',
                    'SiteName',
                    'DomainShortName',
                    'DomainDNSName',
                    'ForestDNSName',
                    'PDCRoleOwner',
                    'SchemaRoleOwner',
                    'IsNativeMode'
                )
                $adsi = New-Object -ComObject ADSystemInfo
                $type = $adsi.GetType()
                $hash = @{}
                foreach($property in $properties){
                    $hash.Add($property,$type.InvokeMember($property,'GetProperty', $Null, $adsi, $Null))
                }
                [pscustomobject]$hash
            }

        function New-Menu {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Title,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Question
            )
            #Add-Type -TypeDefinition 'using namespace System.Management.Automation.Host'
            $Yes = [ChoiceDescription]::new('&Yes')
            $No = [ChoiceDescription]::new('&No')
            $Cancel = [ChoiceDescription]::new('&Cancel')

            $options = [ChoiceDescription[]]($Yes, $No, $Cancel)

            $result = $host.ui.PromptForChoice($Title, $Question, $options, 0)

            switch ($result) {
                0 { 
                    return $true
                    Break
                 }
                1 { 
                    return $false
                    Break
                 }
                2 { 
                    return $false
                    Break
                 }
            }
        }

        function Backup-Key {
            begin {

                Add-Type -AssemblyName System.DirectoryServices.AccountManagement;
                $DisplayName = [System.DirectoryServices.AccountManagement.UserPrincipal]::Current.DisplayName;
                $DisplayName = ($DisplayName).replace(" ","_")
                
                $BLV = Get-BitLockerVolume -MountPoint "C:"
                $BLVKeyProtector = $BLV.KeyProtector | Where-Object {$_.KeyProtectorType -like "recoverypassword"} | Select-Object -Last 1        

                # Store on first external USB drive connected
                $BackuptoUSB = (Get-Volume | Where-Object {($_.DriveLetter-ne "C" -and $_.drivetype -eq "Removable")} | Select-Object driveletter,drivetype -Last 1)
                $numericalFileName = "$DisplayName`_assetnumber`_$date`_BitLocker Recovery Key $(($BLVKeyProtector.KeyProtectorId).Trim('{}')).txt"

            }

            Process{

                # Create text file Contents
                $passwordFileContent = @"
$DisplayName
To verify that this is the correct recovery key, compare the start of the following identifier with the identifier value displayed on your PC.

Identifier:

$(($BLVKeyProtector.KeyProtectorId).Trim('{}'))

If the above identifier matches the one displayed by your PC, then use the following key to unlock your drive.

Recovery Key:

$($BLVKeyProtector.recoverypassword)

If the above identifier doesn't match the one displayed by your PC, then this isn't the right key to unlock your drive.
Try another recovery key, or refer to https://go.microsoft.com/fwlink/?LinkID=260589 for additional assistance.
"@
    
                if($null -ne $BackuptoUSB){
                    if (!(test-path -Path "$($BackuptoUSB.driveletter):\BitLockerKeys")) {
                        [void](New-Item -Path "$($BackuptoUSB.driveletter):\BitLockerKeys" -ItemType Directory -ErrorAction SilentlyContinue -ErrorVariable $InstallingSoftware)  
                    }
                    Write-Verbose -Message "Backing Up Key to a Flash Drive..."
                    $logger.informational("Backing Up Key to a Flash Drive...")
                    $passwordFileContent | Out-File "$($BackuptoUSB.driveletter):\BitLockerKeys\$numericalFileName"
                }
            }                   
        }

    }
    
    process {

        # Make sure that computer OU doesn't have a '/'
        if (!($env:UserName -like "*Some NonDomain User*")) {
            if(((Get-ADSystemInfo).computername).contains('/')) {
                $logger.Alert("$env:COMPUTERNAME cannot be bitlocked because the OU contains a '/' in its name.")
                $logger.Alert("Move $env:COMPUTERNAME to a OU withut a '/' in its name.")
    
                Write-Host "$env:COMPUTERNAME cannot be bitlocked because the OU contains a '/' in its name." -ForegroundColor Red
                Write-Host "Move $env:COMPUTERNAME to a OU withut a '/' in its name." -ForegroundColor Red
                return
            }
        }

        # Check if TPM Version, partition Style,, and firmware meet requirements
            if ($winProductName -like "*10 Pro*" -or $winProductName -like "*10 enterprise*") {
                if ($TPMInfo.Present) {
                    Write-Warning "Checking TPM Features..."
                    Write-Host "TPM is currently present on this machine"
                    switch ($x) {
                        {($TPMInfo.Version -eq "1.2" -and $env:firmware_type -eq "Legacy" -and $partitonStyleCheck -eq "MBR")} {
                            $logger.informational("TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are compatible for Bitlocking")
                            $logger.Alert("The partition style should be moved to GPT, if possible.")
                            Write-Host "TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are compatible for Bitlocking" -ForegroundColor Green
                            Write-Host "The partition style should be moved to GPT, if possible." -ForegroundColor Red
                            $CheckBitlockStatus = $True
                            break
                         }
                        {(($TPMInfo.Version -eq "1.2" -or $TPMInfo.Version -eq "2.0" ) -and $env:firmware_type -eq "UEFI" -and $partitonStyleCheck -eq "GPT")} { 
                            $logger.informational("TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are compatible for Bitlocking")
                            Write-Host "TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are compatible for Bitlocking" -ForegroundColor Green
                            $CheckBitlockStatus = $True
                            break
                         }
                        Default {
                            $logger.Alert("TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are incompatible for Bitlocking")
                            Write-Host "TPM version $($TPMInfo.Version),Firmware Type $env:firmware_type, and partition style $partitonStyleCheck are incompatible for Bitlocking" -ForegroundColor Red
                            $CheckBitlockStatus = $false
                        }
                    }
                }
                else {
                    $logger.Alert("This Product does not contain a TPM chip or it is not enabled. Check BIOS")
                    Write-Host "This Product does not contain a TPM chip or it is not enabled. Check BIOS" -ForegroundColor Red
                }
            }
            else {
                $logger.informational("This OS does not support BitLocking")
                Write-output "This OS does not support BitLocking"
            }

        # Check Current Bitlocker Status
        if ($CheckBitlockStatus -and !$CheckCompatibility) {
            if ($BLV.VolumeStatus -notmatch "FullyEncrypted") {

                Write-Host "BitLocker Status:" -NoNewLine
                Write-Host " $($BLV.VolumeStatus)" -ForegroundColor Red

                $Answer = New-Menu -Title 'Bitlocker' -Question "Do you wish to Bitlock the current computer [$env:computername]"
                if ($Answer) {
                    #if ($TPMInfo.Ready) {
                        # Enable Bitlocker on C:\ for both TPM and numercial recovery key
                        Write-Verbose -Message "Enabling Bitlocker Settings..."
                        $logger.informational("Enabling Bitlocker Settings...")
                        Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes128 -RecoveryPasswordProtector

                        $BLV = Get-BitLockerVolume -MountPoint "C:"
                        $BLVKeyProtector = $BLV.KeyProtector | Where-Object {$_.KeyProtectorType -like "recoverypassword"} | Select-Object -Last 1        

                        # Upload key to AD
                        Write-Verbose -Message "Backing Up Numerical Key to AD..."
                        $logger.informational("Backing Up Numerical Key to AD...")
                        [void](Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $BLVKeyProtector.KeyProtectorId)

                        # Enable notificaction in tray
                        Push-Location -Path "$Home"
                        fvenotify.exe
                    # }
                }
                Else {
                    $logger.informational("Skipping Bitlocker Setup...")
                    Write-Output "Skipping Bitlocker Setup..."
                }

            }
            Else {
                Write-Host "BitLocker Status:" -NoNewLine
                Write-Host " $($BLV.VolumeStatus)" -ForegroundColor Green
            }  
        }

    }
    
    end {
        if ($BLV.VolumeStatus -notmatch "FullyDecrypted") {
            [void](Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $BLVKeyProtector.KeyProtectorId)
        }
        # If not decrypted then back up key to flash drive
        if (!([string]::IsNullOrWhiteSpace($BLV.KeyProtector))) {
            Backup-Key
        }
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
Enable-Encryption