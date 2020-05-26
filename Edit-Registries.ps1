function Edit-Registries {
    <#
    .SYNOPSIS
        Registry edits needed for a build.

    .DESCRIPTION
        Registry edits needed for a build.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Edit-Registries

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
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        $scriptTimer = [Diagnostics.Stopwatch]::StartNew()

        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        "-----------------------------------------------------"
        Write-Warning -Message "Setting Registries..."

        $currentVersionKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion"
    }
    
    process {
        $registryChanges = @(
            @{Output = "Setting Registered Organization to SomeBusiness" ; Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" ; Name = "RegisteredOrganization" ; Value = "SomeBusiness" ; Type = ''},
            @{Output = "Setting Registered Owner to SomeUser" ; Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" ; Name = "RegisteredOwner" ; Value = "SomeUser" ; Type = ''},
            @{Output = "Disabling Advertising ID..." ; Path = "$currentVersionKey\AdvertisingInfo" ; Name = "Enabled" ; Value = "0" ; Type = 'DWord'},
            @{Output = "Turning Off Access to Language List..." ; Path = "HKCU:Control Panel\International\User Profile" ; Name = "HttpAcceptLanguageOptOut" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Turning On Windows Track Apps..." ; Path = "$currentVersionKey\Explorer\Advanced" ; Name = "Start_TrackProgs" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Setting Diagnostic And Usage Data To Basic" ; Path = "HKLM:SOFTWARE\Policies\Microsoft\Windows\DataCollection" ; Name = "AllowTelemetry" ; Value = "1" ; Type = ''},
            @{Output = "Setting Improve Inking & Typing Recognition..." ; Path = "HKCU:Software\Microsoft\Input\TIPC" ; Name = "Enabled" ; Value = "0" ; Type = 'Dword'},
            @{Output = "Turning Off Tailored experiences..." ; Path = "$currentVersionKey\Privacy" ; Name = "TailoredExperiencesWithDiagnosticDataEnabled" ; Value = "0" ; Type = 'Dword'},
            @{Output = "Turning Off Apps Access To Account Info..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\userAccountInformation" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Contacts..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\contacts" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Calendar..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\appointments" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Call History..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\phoneCallHistory" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Email..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\email" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Messages..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\chat" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Access To Radios..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\Radios" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning Off Apps Ability To Share With Other Devices..." ; Path = "$currentVersionKey\CapabilityAccessManager\ConsentStore\bluetoothSync" ; Name = "Value" ; Value = "Deny" ; Type = ''},
            @{Output = "Turning off Background Apps..." ; Path = "$currentVersionKey\BackgroundAccessApplications" ; Name = "GlobalUserDisabled" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Turning Off Windows Default Printer..." ; Path = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" ; Name = "LegacyDefaultPrinterMode" ; Value = "1" ; Type = ''},
            @{Output = "Disabling UAC..." ; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system" ; Name = "EnableLUA" ; Value = "0" ; Type = ''},
            @{Output = "Enabling CMD As Default Shell..." ; Path = "$currentVersionKey\Explorer\Advanced" ; Name = "DontUsePowerShellOnWinX" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Resetting Screenshot Count..." ; Path = "$currentVersionKey\Explorer" ; Name = "ScreenshotIndex" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Unhiding Task View Button..." ; Path = "$currentVersionKey\Explorer\Advanced" ; Name = "ShowTaskViewButton" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Changing Cortnana Icon To Search box..." ; Path = "$currentVersionKey\Search" ; Name = "SearchboxTaskbarMode" ; Value = "2" ; Type = 'Dword'},
            @{Output = "Enabling Hidden Files..." ; Path = "$currentVersionKey\Explorer\Advanced" ; Name = "Hidden" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Enabling Files Extensions..." ; Path = "$currentVersionKey\Explorer\Advanced" ; Name = "HideFileExt" ; Value = "0" ; Type = 'Dword'},
            @{Output = "Disabling Peer Machine Updates..." ; Path = "HKLM:SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" ; Name = "DODownloadMode" ; Value = "0" ; Type = 'Dword'},
            @{Output = "Lowering Time Limit for System Restore Points..." ; Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" ; Name = "SystemRestorePointCreationFrequency" ; Value = "30" ; Type = 'Dword'},
            @{Output = "Hiding People icon..." ; Path = "$currentVersionKey\Explorer\Advanced\People" ; Name = "PeopleBand" ; Value = "o" ; Type = 'Dword'},
            @{Output = "Setting Start Page to https://www.somebusiness.net/SitePages/Home.aspx..." ; Path = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main" ; Name = "Start Page" ; Value = "https://www.somebusiness.net/SitePages/Home.aspx" ; Type = ''},
            @{Output = "Setting Start Page Redirect Cache to http://www.google.com/..." ; Path = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main" ; Name = "Start Page Redirect Cache" ; Value = "http://www.google.com/" ; Type = ''},
            @{Output = "Disabling Edge shortcut creation..." ; Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" ; Name = "DisableEdgeDesktopShortcutCreation" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Disabling Lock screen..." ; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" ; Name = "NoLockScreen" ; Value = "1" ; Type = 'Dword'},
            @{Output = "Enabling Dark Theme..." ; Path = "$currentVersionKey\Themes\Personalize" ; Name = "AppsUseLightTheme" ; Value = "1" ; Type = 'Dword'}
        )

        foreach ($change in $registryChanges) {
            if (!(Test-Path -Path $change.path)){
                $logger.informational("Creating Registry path: $($change.path)")
                [void](New-Item -Path $change.path -WhatIf)
            }
            if (([string]::IsNullOrWhiteSpace($change.Type))){
                $logger.informational("Setting Registry path: $($change.Name) to $($change.Value)")
                Set-ItemProperty -Path $change.path -Name $change.Name -Value $change.Value
            } else {
                $logger.informational("Setting Registry path: $($change.Name) to $($change.Value)")
                Set-ItemProperty -Path $change.path -Name $change.Name -Value $change.Value -Type $change.Type
            }
        }

        # Feedback & Diagnostics
        # Windows should ask for my feedback
        Write-Output "Setting Feedback Frequency to Never"
        $logger.informational("Setting Feedback Frequency to Never")
        [void](New-Item -Path "HKCU:SOFTWARE\Microsoft\Siuf\Rules" -Force)
        Set-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Siuf\Rules" -Name NumberOfSIUFInPeriod -Value 0 -Force
        if ($null -ne (Get-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Siuf\Rules" -Name PeriodInNanoSeconds -ErrorAction SilentlyContinue) ) {
            Remove-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Siuf\Rules" -Name PeriodInNanoSeconds
        }

        # Location-HKLM turns it all off
        # Location Service
        Function Disable-Location {
            Write-Output "Turning Off Location Service For Apps..."
            $logger.informational("Turning Off Location Service For Apps...")
            If (!(Test-Path -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor" -ErrorAction SilentlyContinue)) {
                [void](New-Item -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "Sensor")
                [void](New-Item -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor" -Name "Permissions")
                [void](New-Item -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions" -Name "{BFA794E4-F964-4FDB-90F6-51056BFE4B44}")
                Set-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type Dword -Value 0
                Set-ItemProperty -Path "$currentVersionKey\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "deny"
                Set-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -type Dword -Value 0
            }
            ELSE {
                Set-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type Dword -Value 0
                Set-ItemProperty -Path "$currentVersionKey\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "deny"
                Set-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -type Dword -Value 0
            }
        }
        Disable-Location

        # Tasks-1703+
        # Let apps access tasks
        Function Disable-AppAccess {
            Write-Output "Turning Off Apps Access To Tasks..."
            $logger.informational("Turning Off Apps Access To Tasks...")
            If (!(Get-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{E390DF20-07DF-446D-B962-F5C953062741}" -ErrorAction SilentlyContinue)) {
                [void](New-Item -Path "$currentVersionKey\DeviceAccess\Global" -Name "{E390DF20-07DF-446D-B962-F5C953062741}") 
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{E390DF20-07DF-446D-B962-F5C953062741}" -Name "Type" -Value "InterfaceClass"
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{E390DF20-07DF-446D-B962-F5C953062741}" -Name "InitialAppValue" -Value "Unspecified" 
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{E390DF20-07DF-446D-B962-F5C953062741}" -Name "Value" -Value "Deny" 
            }
            If (!(Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" -ErrorAction SilentlyContinue)) {
                [void](New-Item -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore" -Name "userDataTasks") 
                Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" -Name "Value" -Value "Deny" 
            }
            ELSE {
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{E390DF20-07DF-446D-B962-F5C953062741}" -Name "Value" -Value "Deny" 
                Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" -Name "Value" -Value "Deny" 
            }
        }
        Disable-AppAccess

        # App Diagnostics-1703
        # Let apps access diagnostic information
        function Disable-DiagnosticInfo {
            Write-Output "Turning Off Apps Access To Diagnostic Information..."
            $logger.informational("Turning Off Apps Access To Diagnostic Information...")
            If (!(Get-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" -ErrorAction SilentlyContinue)) {
                [void](New-Item -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}")
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" -Name "Type" -Value "InterfaceClass"
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" -Name "InitialAppValue" -Value "Unspecified"
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" -Name "Value" -Value "Deny"
            }
            ELSE {
                Set-ItemProperty -Path "$currentVersionKey\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" -Name "Value" -Value "Deny"
            }
        }
        Disable-DiagnosticInfo

        Write-Verbose -Message "Finished Setting Registries..."

        "-----------------------------------------------------"
        Write-Warning -Message "Setting Advanced Features..."
        # Enable Storage Sense - automatic disk cleanup - Not applicable to Server-1709
        Function Enable-StorageSense {
            $logger.informational("Enabling Storage Sense...")
            Write-Output "Enabling Storage Sense..."
            If (!(Test-Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy")) {
                [void](New-Item -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Force)
            }
            # Storage Policy 01 Turns on Storage Sense
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1
            # Storage Policy 02 Free up space now
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "02" -Type DWord -Value 1
            # Storage Policy 04 is Delete Temporary files that my apps aren't using
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "04" -Type DWord -Value 1
            # Storage Policy 08 is Delete files in the recycle bin if they have been there for over
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "08" -Type DWord -Value 0
            # Storage Policy 1024 is Run Storage Sense- Scheduling the task
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "1024" -Type DWord -Value 1
            # Storage Policy 2048 is How often to run Storage Sense. ED=1, EW=7, EM=30, WWD=0
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "2048" -Type DWord -Value 7
            # TemporaryFiles---------------------------------------------------------------------------------------------------------------------------------
            # Storage Policy 256 is Delete files in the recycle bin. 1D=1, 14D=14 30D=30, 60D=60
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "256" -Type DWord -Value 0
            # Storage Policy 32 is Delete files in the Downloads folder if they have been there for over
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "32" -Type DWord -Value 0
            # Storage Policy 512 is Delete files in the Downloads folder. 1D=1, 14D=14 30D=30, 60D=60
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "512" -Type DWord -Value 0
            # StoragePoliciesNotified exists when you turn on Storage sense
            Set-ItemProperty -Path "$currentVersionKey\StorageSense\Parameters\StoragePolicy" -Name "StoragePoliciesNotified" -Type DWord -Value 1
        }
        Enable-StorageSense

        # Set Control Panel view to Large icons (Classic)
        Function Set-ControlPanelLargeIcons {
            Write-Output "Setting Control Panel view to large icons..."
            $logger.informational("Setting Control Panel view to large icons...")
            If (!(Test-Path "$currentVersionKey\Explorer\ControlPanel")) {
                [void](New-Item -Path "$currentVersionKey\Explorer\ControlPanel")
            }
            Set-ItemProperty -Path "$currentVersionKey\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
            Set-ItemProperty -Path "$currentVersionKey\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 0
        }
        Set-ControlPanelLargeIcons

        # Disable Application suggestions and automatic installation
        Function Disable-AppSuggestions {
            Write-Output "Disabling Application suggestions..."
            $logger.informational("Disabling Application suggestions...")
            Set-ItemProperty -Path "$currentVersionKey\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "$currentVersionKey\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "$currentVersionKey\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "$currentVersionKey\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0
            If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
                [void](New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force)
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1
        }

        Function Show-TaskManagerDetails {
            Write-Output "Showing task manager details..."
            $logger.informational("Showing task manager details...")
            $taskmgr = Start-Process -WindowStyle Hidden -FilePath taskmgr.exe -PassThru
            $timeout = 30000
            $sleep = 100
            Do {
                Start-Sleep -Milliseconds $sleep
                $timeout -= $sleep
                $preferences = Get-ItemProperty -Path "$currentVersionKey\TaskManager" -Name "Preferences" -ErrorAction SilentlyContinue
            } Until ($preferences -or $timeout -le 0)
            Stop-Process $taskmgr
            If ($preferences) {
                $preferences.Preferences[28] = 0
                Set-ItemProperty -Path "$currentVersionKey\TaskManager" -Name "Preferences" -Type Binary -Value $preferences.Preferences
            }
        }
        Show-TaskManagerDetails

        Function Enable-Numlock {
            Write-Output "Enabling NumLock after startup..."
            $logger.informational("Enabling NumLock after startup...")
            If (!(Test-Path "HKU:")) {
                New-PSDrive -Name "HKU" -PSProvider "Registry" -Root "HKEY_USERS" | Out-Null
            }
            Set-ItemProperty -Path "HKU:\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" -Type DWord -Value 2147483650
            Add-Type -AssemblyName System.Windows.Forms
            If (!([System.Windows.Forms.Control]::IsKeyLocked('NumLock'))) {
                $wsh = New-Object -ComObject WScript.Shell
                $wsh.SendKeys('{NUMLOCK}')
            }
        }
        Enable-Numlock
    }
    
    end {
        $scriptTimer.stop()
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        $logger.informational("Script Runtime:$($scriptTimer.Elapsed.ToString())")
    }
}