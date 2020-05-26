function Merge-RegistryFile {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        "-----------------------------------------------------"
        Write-Warning -Message "Running Registry Files..."
        # Silently runs the listed Registries
        $registryPaths = @(
            @{Output = "Running DisableUAC.reg" ; Path = "\\Server\Path\Here\Settings\REG\DisableUAC.reg" },
            @{Output = "Running Blue Screen Settings" ; Path = "\\Server\Path\Here\Settings\REG\BlueScreenSettings.reg" },
            @{Output = "Running Cam and Mic Fix" ; Path = "\\Server\Path\Here\Settings\REG\CamAndMicFix.reg" },
            @{Output = "Running Active X Disable for Excel" ; Path = "\\Server\Path\Here\Settings\REG\activeXdisable.reg" },
            @{Output = "Running onyxCompatibility.reg" ; Path = "\\Server\Path\Here\Settings\IE\onyxCompatibility.reg" },
            @{Output = "Running userPreferences.reg" ; Path = "\\Server\Path\Here\Settings\IE\userPreferences.reg" },
            #@{Output = "Running googleIESet.reg" ; Path = "\\Server\Path\Here\Settings\IE\googleIESet.reg"},
            @{Output = "Running defaultScopes.reg" ; Path = "\\Server\Path\Here\Settings\IE\defaultScopes.reg" },
            @{Output = "Running FavoritesBar.reg" ; Path = "\\Server\Path\Here\Settings\IE\FavoritesBar.reg" },
            @{Output = "Running PopupBlockerAllow.reg" ; Path = "\\Server\Path\Here\Settings\IE\PopupBlockerAllow.reg" },
            @{Output = "Running TypedPaths.reg" ; Path = "\\Server\Path\Here\Settings\REG\TypedPaths.reg" },
            @{Output = "Running GoogleChrome.reg" ; Path = "\\Server\Path\Here\Settings\Chrome\GoogleChrome.reg" },
            @{Output = "Running OutlookZeroConfig.reg" ; Path = "\\Server\Path\Here\Settings\REG\OutlookZeroConfig.reg" },
            @{Output = "Running Support.reg" ; Path = "\\Server\Path\Here\Settings\REG\Support.reg" }
        )
    }
    
    process {
        foreach ($registryPath in $registryPaths) {
            if (Test-Path -path $registryPath.Path) {
                If ($registryPath.output -like "*zeroConfig*") {
                    If (!(Get-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Outlook\AutoDiscover" -Name "zeroconfigexchangeonce" -ErrorAction SilentlyContinue)) {
                        Write-Output "$($registryPath.Output)"
                        Regedit /s $($registryPath.Path)
                        $logger.informational("$($registryPath.Output) loaded")
                    }
                }
                elseif (!($registryPath.output -like "*zeroConfig*")) {
                    Write-Output "$($registryPath.Output)"
                    Regedit /s $($registryPath.Path)
                    $logger.informational("$($registryPath.Output) loaded")
                } 
            }
            
            if ($? -ne $true) {
                $logger.Error("$($registryPath.Output) Failed to load properly")
                Write-Host "$($registryPath.Output) Failed to load properly" -ForegroundColor Red
            }
        }
    }
    
    end {
        Write-Verbose -Message "Finished Merging Registry Files"
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}