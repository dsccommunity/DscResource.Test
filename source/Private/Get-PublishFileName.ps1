<#
    .SYNOPSIS
        This command will return a filename without extension and without any
        starting numeric value followed by a dash (-).

    .PARAMETER Path
        The path to the example for which the filename should be returned.

    .OUTPUTS
        Returns a filename without extension and without any starting numeric
        value followed by a dash (-).
#>
function Get-PublishFileName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    # Get the filename without extension.
    $filenameWithoutExtension = (Get-Item -Path $Path).BaseName

    <#
        Resource modules using auto-documentation uses a numeric value followed
        by a dash ('-') to be able to control the order of the example in
        the documentation. That will not be used when publishing, so remove
        it here from the name that is compared to the configuration name.
    #>
    return $filenameWithoutExtension -replace '^[0-9]+-'
}
