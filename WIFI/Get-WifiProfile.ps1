function Get-WifiProfile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]$Name
    )
    Begin {
        $list = ((netsh.exe wlan show profiles) -match '\s{2,}:\s') -replace '.*:\s' , ''
        $ProfileList = $List | ForEach-Object { [pscustomobject]@{Name = $_ } }
    }
    Process {
        Foreach ($WLANProfile in $Name) {
            $ProfileList | Where-Object { $_.Name -match $WLANProfile }
        }
    }
    End {
        If ($Null -eq $Name) {
            $Profilelist
        }
    }
}
