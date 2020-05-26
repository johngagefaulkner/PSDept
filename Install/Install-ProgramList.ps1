function Install-ProgramList {
    <#
    .SYNOPSIS
        A brief description of the function or script.

    .DESCRIPTION
        A longer description.
        
    .PARAMETER InputObject
        Accepts a specific object type with the programs name, if it's installed, and if its scripted installation.
        
    .PARAMETER Program
        A dynamically generated, tab completing parameter by taking input from the json. It converts this into a validated set.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .EXAMPLE
        $list = Compare-ProgramList -Path "\\server\path\here\Applications.json"
        Install-ProgramList -InputObject $list

    .EXAMPLE
        Compare-ProgramList -Path "\\server\path\here\Applications.json" | Install-ProgramList

    .EXAMPLE
        Install-ProgramList -Program '7-Zip'

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding(DefaultParameterSetName = "InputObject")]
    [Alias()]
    [OutputType([String])]
    Param (        
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "InputObject")]
        [ValidateNotNullOrEmpty()]
        [Psobject]$InputObject,
        
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )

    DynamicParam {
        
        # Generate and set the ValidateSet
        $fname = "\\Server\Path\Here\Settings\JSON\Applications.json" 
        $arrSet = (ConvertFrom-Json (Get-Content $fname -Raw))

        # Set the dynamic parameters' name
        $ParamName_Program = 'Program'
        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 1
        $ParameterAttribute.ParameterSetName = "ProgramList"
        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute) 
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet.Program.PSObject.Properties.name)    
        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)
        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_Program, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParamName_Program, $RuntimeParameter)
        return $RuntimeParameterDictionary

    }
    
    begin {
        # Add Logging block
        try {
            if (!("PSLogger" -as [type])) {
                $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
                ."\\Server\Path\Here\Logging.ps1"
                $logger = [PSLogger]::new($logPath, $callingScript)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")

        # First block to add/change stuff in
        try {
            #$Program = $PsBoundParameters[$ParamName_Program]
            ."\\Server\Path\Here\Settings\Scripts\Get-NearestDomain.ps1"
            $nearestDomain = (Get-NearestDomain -Path "\\Server\Path\Here\Settings\JSON\DCList.json")

        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
        
    }
    
    process {
    
        try {

            if ( $PSBoundParameters.ContainsKey("InputObject") ) {
                foreach ($value in $PSBoundParameters.Values){
                    if ($value.Installed -eq $false -and $value.AutoInstallSupport -eq $true) {

                        $logger.Informational("$($value.name) is not installed and supports auto installation.")
                        $install = $arrSet.Program.($value.name)

                        if ($install.filename.contains(".ps1")){
                            $logger.Informational("Installing via ps1 file \\$nearestDomain\$($install.source)\$($install.filename)")
                            ."\\$nearestDomain\$($install.source)\$($install.filename)"
                        } else {
                            $logger.Informational("Installing via bat file \\$nearestDomain\$($install.source)\$($install.filename)")
                            "Start-Process -FilePath $Env:ComSpec -ArgumentList '/c \\$nearestDomain\$($install.source)\$($install.filename)'"
                        }

                    } elseif ($value.Installed -eq $false -and $value.AutoInstallSupport -eq $false) {
                        $logger.Informational("There is no auto install support for $($value.name). You will need to manually install this software.")
                        "There is no auto install support for $($value.name). You will need to manually install this software."
                    }
                }
            }
    
            if ( $PSBoundParameters.ContainsKey("Program") ) {
                foreach ($value in $PSBoundParameters.Values){

                    $install = $arrSet.Program.$value

                    if ($install.filename.contains(".ps1")){
                        $logger.Informational("Installing via ps1 file \\$nearestDomain\$($install.source)\$($install.filename)")
                        ."\\$nearestDomain\$($install.source)\$($install.filename)"
                    } else {
                        $logger.Informational("Installing via bat file \\$nearestDomain\$($install.source)\$($install.filename)")
                        "Start-Process -FilePath $Env:ComSpec -ArgumentList '/c \\$nearestDomain\$($install.source)\$($install.filename)'"
                    }
                    
                } 
            }
        }
        catch {
            $logger.Error("$PSitem")
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

    }
    
    end {
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
        #$logger.Remove()
        
    }
}

