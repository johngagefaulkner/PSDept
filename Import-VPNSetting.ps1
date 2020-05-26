function Import-VPNSetting {
	<#
    .SYNOPSIS
        Imports vpn setting files.

    .DESCRIPTION
        Imports vpn setting files. Clears old ones. Checks to see if cisco vpn anyconnect is installed first.

    .PARAMETER Path
		Folder path to a list vpn settings.

    .PARAMETER NamingScheme
		Naming scheme to find which files to copy.

    .PARAMETER Download
		Download path for the files.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
		Import-VPNSetting -Path "\\server\path\here\2FA"

    .EXAMPLE
		Import-VPNSetting -Path "\\server\path\here\2FA" -NamingScheme "*Okta*.xml"

    .EXAMPLE
		Import-VPNSetting -Path "\\server\path\here\2FA" -Download "$home\Downloads\2FA"
		
    .EXAMPLE
        Import-VPNSetting -Path "\\server\path\here\2FA" -NamingScheme "*Okta*.xml" -Download "$home\desktop\2FA"

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
            if (-Not ($_ | Test-Path) ) {
                throw "Folder does not exist"
            }
            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw "The path argument must be a folder. File paths are not allowed."
            }
            return $true 
        })]
		[string]$Path,

		[Parameter(Mandatory=$false)]
		[string]$NamingScheme = "*Okta*.xml",

		[Parameter(Mandatory=$false)]
		[string]$Download = "$home\Downloads\2FA",

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
		
		$logger.Informational("Importing $(split-path $PSBoundParameters.Path -Leaf)")

		[string]$64bit = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
		[array]$Properties = @("DisplayName","UninstallString")
		$installCheck = (Get-ChildItem -Path $64bit | Get-ItemProperty).Where({$_.DisplayName -like "*Cisco Anyconnect*" })| Select-Object -Property $Properties
		if ($null -eq $installCheck.UninstallString) {
			$logger.Informational("Cisco Anyconnect is not installed. Please contact Help Desk at x5210, if you need it installed.")
			Throw "Cisco Anyconnect is not installed. Please contact Help Desk at x5210, if you need it installed."
		}

		switch ($nearestDomain) {
			DCHQ { $Profile = 'US' ; break }
			DC10 { $Profile = 'UK' ; break }
			DC04 { $Profile = 'AU' ; break }
			Default { 
				"nearestDomain: [$nearestDomain] is not apart of the configured list"
				$logger.Warning("nearestDomain: [$nearestDomain] is not apart of the configured list")
				$logger.Informational("Defaulting to US Profiling")  
				$Profile = 'US'
			}
		}
        
        $VpnSource = "$Path\$Profile"
		$copy = RoboCopy $VpnSource $Download /mir /mt:4
		if ($copy.lastexitcode -gt 7) {
			$logger.warning("[Copy Exitcode]:[$($copy.ExitCode)] Robocopy indicates an issue with copying")
			"[Copy Exitcode]:[$($copy.ExitCode)] Robocopy indicates an issue with copying"
		}
		
		Get-Process -Name "vpnui" -ErrorAction SilentlyContinue | Stop-Process -Force
		
		$VPNSettings = @(
			@{Path = "$env:LOCALAPPDATA\Cisco\Cisco AnyConnect Secure Mobility Client" ; Files = "preferences.xml" }
			@{Path = "$env:ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile" ; Files = "AnyConnectProfile.xsd" ,$NamingScheme }
		)
	}
	
	process {
		# Remove old files
		foreach ($Setting in $VPNSettings) {
			$logger.warning("Removing $($Setting.Path)\*")
			Get-ChildItem -path "$($Setting.Path)\*" -Recurse | Remove-Item -Force

			$logger.Informational("Copying $Download\$($Setting.Files) to $($Setting.Path)")
			$copy = RoboCopy $Download $Setting.Path $Setting.Files /mt:4
			
			if ($copy.exitcode -gt 7) {
				$logger.warning("[Copy Exitcode]:[$($copy.ExitCode)] Robocopy indicates an issue with copying")
				Throw "[Copy Exitcode]:[$($copy.ExitCode)] Robocopy indicates an issue with copying"
			}
		}
	}
	
	end {
		# remove downloaded files
		if (Test-Path -Path $Download) {
			$logger.notice("Removing $Download")
			Remove-Item -Path $Download -Recurse -Force
		}
		$logger.Notice("Finished $($MyInvocation.MyCommand) script")
	}
}
