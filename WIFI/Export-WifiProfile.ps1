function Export-WifiProfile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]$Name,
        
        [string]$Destination = "$Home\desktop"
    )
    Begin {

     }
    Process {
        if ($null -eq $Name){
            $result=(netsh wlan export profile key=clear folder="$Destination")
            $result
        } else {
            Foreach ($item in $Name) {
                $result = (netsh wlan export profile name=$item folder="$Destination")
                $result
            }
        }
    }
}