function Set-WallPaper {
    <#
    .SYNOPSIS
        Sets the wallpaper and its style.

    .DESCRIPTION
        Sets the wallpaper and its style.

    .PARAMETER Wallpaper
        File path to a single. The file specified in the path argument must be JPG, JPEG, BMP, DIB, PNG, JFIF, JPE, GIF, TIF, TIFF, or WDP

    .PARAMETER WallpaperStyle
        Style that you want the wallpaper to be. Must be 'Fill', 'Fit', 'Stretch', 'Center', 'Tile', or 'Span'

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        Set-WallPaper -WallPaper "\\server\path\chosen.jpg"

    .EXAMPLE
        Set-WallPaper -WallPaper "\\server\path\chosen.jpg" -WallpaperStyle 'Center'

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
                throw "File does not exist"
            }
            if (-Not ($_ | Test-Path -PathType Leaf) ) {
                throw "The path argument must be a file. Folder paths are not allowed."
            }
            if ($_ -notmatch "(\.JPG|\.JPEG|\.BMP\.DIB|\.PNG|\.JFIF|\.JPE|\.GIF|\.TIF|\.TIFF|\.WDP)") {
                throw "The file specified in the path argument must be JPG, JPEG, BMP, DIB, PNG, JFIF, JPE, GIF, TIF, TIFF, or WDP"
            }
            return $true 
        })]
        [string]$WallPaper,
        
        [ValidateSet('Fill', 'Fit', 'Stretch', 'Center', 'Tile', 'Span')]
        [string]$WallpaperStyle = 'Fill',

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

        Write-Output "Setting Background..."
        $logger.informational("Setting Background...")
        
        Add-Type -TypeDefinition '
            using System;
            using System.Runtime.InteropServices;
            using Microsoft.Win32;
            namespace Wallpaper {
                public class Setter {
                    public const int SetDesktopWallpaper = 20;
                    public const int UpdateIniFile       = 0x01;
                    public const int SendWinIniChange    = 0x02;
                    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                    private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
                    public static void SetWallpaper ( string path ) {
                        SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
                    }
                }
            }
        '
        #remove cached files to help change happen
        #Remove-Item -Path "$($env:APPDATA)\Microsoft\Windows\Themes\CachedFiles" -Recurse -Force -ErrorAction SilentlyContinue    
    
        $fit = @{ 'Fill' = 10; 'Fit' = 6; 'Stretch' = 2; 'Center' = 0; 'Tile' = '99'; 'Span' = '22' }
    
    }
    
    process {
        if ($WallpaperStyle -eq 'Tile') {
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -value 0;
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -value 1;
        } else {
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -value $fit[$WallpaperStyle];
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -value 0;
        }
    }
    
    end {
        [Wallpaper.Setter]::SetWallpaper($WallPaper);
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
