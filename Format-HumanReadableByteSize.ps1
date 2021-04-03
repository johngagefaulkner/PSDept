function Format-HumanReadableByteSize {
    <#
    .SYNOPSIS
        Format byte sizes to something human readable.

    .DESCRIPTION
        Format byte sizes to something human readable.

    .PARAMETER InputObject
        Takes any byte object.

    .INPUTS
        Int

    .OUTPUTS
        String

    .EXAMPLE
        Format-HumanReadableByteSize -InputObject 10000

    .EXAMPLE
        1000 | Format-HumanReadableByteSize

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    param (
        [parameter(ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [double]$InputObject
    )

    # Handle this before we get NaN from trying to compute the logarithm of zero
    if ($InputObject -eq 0) {
        return "0 Bytes"
    }
    
    $magnitude = [math]::truncate([math]::log($InputObject, 1024))
    $normalized = $InputObject / [math]::pow(1024, $magnitude)
    
    $magnitudeName = switch ($magnitude) {
        0 { "Bytes"; Break }
        1 { "KB"; Break }
        2 { "MB"; Break }
        3 { "GB"; Break }
        4 { "TB"; Break }
        5 { "PB"; Break }
        Default { Throw "Byte value too big" }
    }
    
    "{0:n2} {1}" -f ($normalized, $magnitudeName)
}
