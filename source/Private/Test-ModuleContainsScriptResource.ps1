
<#
    .SYNOPSIS
        Tests if a module contains a script resource.

    .PARAMETER ModulePath
        The path to the module to test.
#>
function Test-ModuleContainsScriptResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]
        $ModulePath
    )

    $dscResourcesFolderFilePath = Join-Path -Path $ModulePath -ChildPath 'DscResources'
    $mofSchemaFiles = Get-ChildItem -Path $dscResourcesFolderFilePath -Filter '*.schema.mof' -File -Recurse

    return ($null -ne $mofSchemaFiles)
}
