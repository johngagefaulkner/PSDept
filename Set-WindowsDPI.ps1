function Set-WindowsDPI {
    [CmdletBinding()]
    param (
    )
    
    begin {        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        $Monitors = (Get-CimInstance -Namespace "root\wmi" -ClassName WmiMonitorListedSupportedSourceModes)

        <# Improved and readable
        $MonitorList = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorListedSupportedSourceModes)
        $sortedModes = foreach ($Index in 0..$MonitorList.GetUpperBound(0)) {

            $PrefSourceMode = $MonitorList[$Index].PreferredMonitorSourceModeIndex
            [PSCustomObject]@{
                Res_Horizontal = $MonitorList[$Index].MonitorSourceModes.HorizontalActivePixels[$PrefSourceMode]
                Res_Vertical = $MonitorList[$Index].MonitorSourceModes.VerticalActivePixels[$PrefSourceMode]
            } | Select-Object @{N = "MaxRes"; E = { "$($_.Res_Horizontal)x$($_.Res_Vertical)" } }
        }
        $sortedModes
        #>
    }
    
    process {
        # Finds the native resolution of the Monitor
        # Changes DPI to a scale of 100%-120=125% 144=150% 192=200% 216=225%
        foreach ($Monitor in $Monitors) {
            <# Get the id for this Monitor
            $currentId =  $IDs |? {$_.InstanceName -eq $Monitor.InstanceName}#>
            # Sort the available modes by display area (width*height)
            $sortedModes = $Monitors.MonitorSourceModes | Where-Object { ($_.HorizontalActivePixels -gt "1000" -and $_.VerticalActivePixels -gt "768") } |
                Sort-Object -property { $_.HorizontalActivePixels * $_.VerticalActivePixels }
            $maxModes = $sortedModes | Select-Object @{N = "MaxRes"; E = { "$($_.HorizontalActivePixels)x$($_.VerticalActivePixels)" } }
            $maxres = ($maxModes | Select-Object -last 1).maxres
            switch ($maxres) {
                "1920x1080" { $LogPixels = "96"; break }
                "2560x1440" { $LogPixels = "144"; break }
                #"3200x1800" { $LogPixels = "168"; break } HP possible issue
                "3840x2160" { $LogPixels = "216"; break }
                default { $LogPixels = "96" }
            }
        }
    }
    
    end {
        
        # Creates Win8DpiScaling registry if it doesn't exist
        If (!(Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name "Win8DpiScaling" -ErrorAction SilentlyContinue)) {
            [void](New-ItemProperty -Path "HKCU:\Control Panel\Desktop\" -Name "Win8DpiScaling" -Type DWord -Value 1)
        }
        ELSE {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Win8DpiScaling" -Type DWord -Value 1
        }
        # Creates LogPixels registry if it doesn't exist
        If (!(Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name "LogPixels" -ErrorAction SilentlyContinue)) {
            [void](New-ItemProperty -Path "HKCU:\Control Panel\Desktop\" -Name "LogPixels" -Type DWord -Value $LogPixels)
        }
        ELSE {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "LogPixels" -Type DWord -Value $LogPixels
        }
        Write-Verbose -Message "Finished Setting Monitor DPI"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
