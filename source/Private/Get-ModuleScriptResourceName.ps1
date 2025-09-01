
<#
    .SYNOPSIS
        Retrieves the names of all script resources for the given module.

    .PARAMETER ModulePath
        The path to the module to retrieve the script resource names of.
#>
function Get-ModuleScriptResourceName
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]
        $ModulePath
    )

    $dscResourcesFolderFilePath = Join-Path -Path $ModulePath -ChildPath 'DscResources'
    $mofSchemaFiles = Get-ChildItem -Path $dscResourcesFolderFilePath -Filter '*.schema.mof' -Recurse

    $scriptResourceNames = foreach ($mofSchemaFile in $mofSchemaFiles)
    {
        ($mofSchemaFile.BaseName -replace '.schema', '')
    }

    return $scriptResourceNames
}
