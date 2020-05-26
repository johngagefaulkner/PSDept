function Sync-WindowsTimeService {
    <#
    .SYNOPSIS
        Sync the current computers time service.

    .DESCRIPTION
        Sync the current computers time service to a server. Test the connection to the server before proceeding.
        If there is no connection then the script will stop. If it fails the command then it will output the command for you to use
        manually.

    .PARAMETER ComputerName
        Type a computer/server name that you want to sync the current machine to. It will test the connection before making any changes.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Sync-WindowsTimeService -ComputerName "console.real.root.local"

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
        [ValidateScript( {
            if (-Not (test-connection -ComputerName $_ -quiet -count 1) ) {
                throw "Connection to $_ failed"
            }
            return $true 
        })]
        [string]$ComputerName,

        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath,$callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
    
        Write-Verbose -Message "Building Time Parameters..."

        $timeArgs = @{
            FilePath      = 'w32tm.exe'
            ArgumentList  = @(
                "/config"
                "/manualpeerlist:$env:COMPUTERNAME"
                "/syncfromflags:manual"
                "/reliable:yes"
                "/update"
            )
            Wait          = $True
            NoNewWindow   = $True
            ErrorAction   = "Stop"
            ErrorVariable = "+TimeSync"
            PassThru      = $True
        }
    }
    
    process {
        Write-Verbose -Message "Running DC Time Sync..."
        try {
            if ($env:UserName -like "*Some NonDomain User*") {
                $logger.Informational("Logged in as $env:UserName, Cannot Run Time Fix.")
                Write-Output "Logged in as $env:UserName, Cannot Run Time Fix."
                $logger.Informational("Setting Timezone to Central Standard Time...")
                Set-TimeZone -Id "Central Standard Time"
            }
            else {
                Write-Output "Running DC Time Sync..."
                $time = Start-Process @timeArgs
                
                $logger.Informational("Setting Timezone to Automatic...")
                Write-Output "Setting Timezone to Automatic..."
               
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -type Dword -Value 3
                $logger.Informational("Setting Timezone to Central Standard Time...")
                Set-TimeZone -Id "Central Standard Time"
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    end {
        Write-Verbose -Message "Finished DC Time Sync"
        if ($null -ne $time.ExitCode -and $time.ExitCode -eq 0) {
            $logger.Informational("[Time exitcode]:$($time.exitcode) Successful")
            Write-Output "[Time exitcode]:$($time.exitcode) Successful"
        }
        else {
            $logger.Warning("[Time exitcode]:$($time.exitcode) Failed.")
            Write-warning -message "[Time exitcode]:$($time.exitcode) Failed."

            $logger.Warning("Please Run Manually $($timeArgs.FilePath) $($timeArgs.ArgumentList)")
            Write-Output "Please Run Manually $($timeArgs.FilePath) $($timeArgs.ArgumentList)"
        }
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
