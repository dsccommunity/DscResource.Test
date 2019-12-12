
<#
    .SYNOPSIS
        Tests if a module contains a class resource.

    .PARAMETER ModulePath
        The path to the module to test.
#>
function Test-ModuleContainsClassResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]
        $ModulePath
    )

    $psm1Files = Get-Psm1FileList -FilePath $ModulePath

    foreach ($psm1File in $psm1Files)
    {
        if (Test-FileContainsClassResource -FilePath $psm1File.FullName)
        {
            return $true
        }
    }

    return $false
}
