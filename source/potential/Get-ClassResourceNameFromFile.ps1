<#
    .SYNOPSIS
        Retrieves the name(s) of any DSC class resources from a PowerShell file.

    .PARAMETER FilePath
        The full path to the file to test.

    .EXAMPLE
        Get-ClassResourceNameFromFile -FilePath 'c:\mymodule\myclassmodule.psm1'

        This command will get any DSC class resource names from the myclassmodule module.
#>
function Get-ClassResourceNameFromFile
{
    [OutputType([String[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]
        $FilePath
    )

    $classResourceNames = [String[]]@()

    if (Test-FileContainsClassResource -FilePath $FilePath)
    {
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

        $typeDefinitionAsts = $fileAst.FindAll( { $args[0] -is [System.Management.Automation.Language.TypeDefinitionAst] }, $false)
        foreach ($typeDefinitionAst in $typeDefinitionAsts)
        {
            if ($typeDefinitionAst.Attributes.TypeName.Name -ieq 'DscResource')
            {
                $classResourceNames += $typeDefinitionAst.Name
            }
        }
    }

    return $classResourceNames
}
