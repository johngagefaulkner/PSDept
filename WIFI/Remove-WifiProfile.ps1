function Remove-WifiProfile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]$Name
    )
    begin { }
    process {
        Foreach ($item in $Name) {
            $result=(netsh.exe wlan delete profile $item)
            $result
        }
    }
}