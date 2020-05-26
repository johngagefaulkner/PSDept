function Get-MachineInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()] 
        [string[]]$ComputerName = $env:COMPUTERNAME
        
    )
    function New-AutoCimSession {
        <#
        .SYNOPSIS
            Creates CimSessions to remote computer(s), automatically determining if the WSMAN
            or Dcom protocol should be used.
        .DESCRIPTION
            New-AutoCimSession is a function that is designed to create CimSessions to one or more
            computers, automatically determining if the default WSMAN protocol or the backwards
            compatible Dcom protocol should be used. PowerShell version 3 is required on the
            computer that this function is being run on, but PowerShell does not need to be
            installed at all on the remote computer.
        .PARAMETER ComputerName
            The name of the remote computer(s). This parameter accepts pipeline input. The local
            computer is the default.
        .PARAMETER Credential
            Specifies a user account that has permission to perform this action. The default is
            the current user.
        .EXAMPLE
            New-AutoCimSession -ComputerName Server01, Server02
        .EXAMPLE
            New-AutoCimSession -ComputerName Server01, Server02 -Credential (Get-Credential)
        .EXAMPLE
            Get-Content -Path C:\Servers.txt | New-AutoCimSession
        .INPUTS
            String
        .OUTPUTS
            Microsoft.Management.Infrastructure.CimSession
        #>
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [ValidateNotNullorEmpty()]
            [string[]]$ComputerName = $env:COMPUTERNAME,
     
            [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
        )
    
        BEGIN {
            $Opt = New-CimSessionOption -Protocol Dcom
    
            $SessionParams = @{
                #Name = $ComputerName
                ErrorAction = 'Stop'
            }
    
            If ($PSBoundParameters['Credential']) {
                $SessionParams.Credential = $Credential
            }
        }
    
        PROCESS {
            foreach ($Computer in $ComputerName) {
                $SessionParams.ComputerName = $Computer
    
                if ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: ([3-9]|[1-9][0-9]+)\.[0-9]+') {
                    try {
                        Write-Verbose -Message "Attempting to connect to $Computer using the WSMAN protocol."
                        New-CimSession @SessionParams
                    }
                    catch {
                        Write-Warning -Message "Unable to connect to $Computer using the WSMAN protocol. Verify your credentials and try again."
                    }
                }
     
                else {
                    $SessionParams.SessionOption = $Opt
    
                    try {
                        Write-Verbose -Message "Attempting to connect to $Computer using the DCOM protocol."
                        New-CimSession @SessionParams
                    }
                    catch {
                        Write-Warning -Message "Unable to connect to $Computer using the WSMAN or DCOM protocol. Verify $Computer is online and try again."
                    }
    
                    $SessionParams.Remove('SessionOption')
                }            
            }
        }
    }

    $ComputerInfo = foreach ($Computer in $ComputerName) {
        try {
            $session = New-AutoCimSession -ComputerName $Computer
            $computerSystem = (Get-CimInstance -ClassName 'Win32_ComputerSystem' -property Manufacturer, Model, TotalPhysicalMemory, UserName -CIMSession $session)
            $computerBIOS = (Get-CimInstance -ClassName 'Win32_BIOS' -property SerialNumber -CIMSession $session)
            $computerOS = (Get-CimInstance -ClassName 'Win32_OperatingSystem' -property caption -CIMSession $session)
            $computerCPU = (Get-CimInstance -ClassName 'Win32_Processor' -property Name, numberofcores -CIMSession $session)
            $computerHDD = (Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DeviceId = "C:"' -CIMSession $session)
            $computerMacAddress = (Get-CimInstance -ClassName 'win32_networkadapterconfiguration' -property Description, MACAddress -CIMSession $session | 
                Where-Object { ($null -ne $_.macaddress) -and ($_.Description -like "*Wireless*" -or $_.Description -like "*Ethernet*" -or $_.Description -like "*ac*") })
                    
            $ethernet = "$(($computerMacAddress | Where-Object {$_.description -like "ethernet*"}).Description): [$(($computerMacAddress | Where-Object {$_.description -like "ethernet*"}).MACAddress -replace ":", "-")]"
            $wireless ="$(($computerMacAddress | Where-Object {$_.description -like "*Wireless*"}).Description): [$(($computerMacAddress | Where-Object {$_.description -like "*Wireless*"}).MACAddress -replace ":", "-")]"                    
            $VirtualAdapter ="$(($computerMacAddress | Where-Object {$_.description -like "*virtual * adapter*"}).Description): [$(($computerMacAddress | Where-Object {$_.description -like "*virtual * adapter*"}).MACAddress -replace ":", "-")]"
            
            [PSCUSTOMOBJECT]@{
                ComputerName   = $computerSystem.Name
                Manufacturer   = $computerSystem.Manufacturer
                Model          = $computerSystem.Model
                SerialNumber   = $computerBIOS.SerialNumber
                CPU            = $($computerCPU.Name)
                Cores          = $($computerCPU.numberofcores)
                DriveCapacity  = "$([Math]::Round(($computerHDD.Size/1GB)))GB"
                DriveSpace     = "{0:P2}" -f ($computerHDD.FreeSpace / $computerHDD.Size) + " Free (" + "{0:N2}" -f ($computerHDD.FreeSpace / 1GB) + "GB)"
                RAM            = "$([Math]::Round(($computerSystem.TotalPhysicalMemory/1GB)))GB"
                OS             = $computerOS.caption
                Ethernet       = if ($ethernet -match '\: \[\]'){} else {$ethernet}
                WiFi           = if ($wireless -match '\: \[\]'){} else {$wireless}
                VirtualAdapter = if ($VirtualAdapter -match '\: \[\]'){} else {$VirtualAdapter}
                CurrentUser    = $computerSystem.UserName
            }
        }
        catch {
            Write-Host "$_.Exception.Message" -ForegroundColor Red
        }
   
        # Remove Cim sessions
        #foreach ($Computer in $RemoteMachine) {
        #Get-Cimsession | Remove-CimSession
        #}

    }
    $ComputerInfo
}