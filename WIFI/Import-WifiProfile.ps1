function Import-WifiProfile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]$Name
    )
    Begin { }
    Process {
        Foreach ($item in $Name) {
            $result=(netsh wlan add profile filename=$item user=all)
            $result
        }
    }
}