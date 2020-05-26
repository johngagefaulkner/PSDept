function Test-IsMutexAvailable {
    try {
        $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
        $Mutex.Dispose();
        $logger.Informational("Mutex unavailable")
        return $false
    }
    catch {
        $logger.Informational("Mutex available")
        return $true
    }
}