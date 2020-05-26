function Reset-WindowsIndexing {
    param (
        [System.Object]$Service = (Get-Service -name "WSearch")
    )
    
    try {
        $windowsIndexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
        $process = "SearchIndexer.exe"

        if (Get-Process -Name $process -ea SilentlyContinue) {
            $logger.Informational("Stopping $process process")
            Get-Process -Name $process | Stop-Process
        }

        Stop-Service $service.Name
        $logger.Informational("Waiting for $($service.Name) service to stop")
        $service.WaitForStatus('Stopped', '00:00:030')
        Set-Service $service.Name -StartupType Disabled

        if (test-path -Path $windowsIndexPath) {
            remove-item -Path $windowsIndexPath -Force | out-null
            $logger.Informational("removing $windowsIndexPath")
            Write-Output "Rebuilding Search Index"
        }
        
        Set-Service $service.Name -StartupType Automatic
        Start-Service $service.Name
        $logger.Informational("Waiting for $($service.Name) service to start")
        $service.WaitForStatus('Running', '00:00:30')
    
        if ((Get-Service -Name $service.name).Status -eq "Running") {
            Write-Output "$($service.name) Service Started"
        }
    }
    catch {
        $logger.Error("$PSitem")
        $PSCmdlet.ThrowTerminatingError($PSitem)
    }
    $logger.Notice("Finished $($MyInvocation.MyCommand) script")
}
