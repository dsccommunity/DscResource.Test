<#
    .SYNOPSIS
        Tests if a PowerShell file contains a DSC class resource.

    .DESCRIPTION
        This function parses a PowerShell file using the Abstract Syntax Tree (AST)
        to determine if it contains any class-based DSC resources. It looks for 
        class definitions that have a [DscResource] attribute, regardless of any
        parameters the attribute may have.

    .PARAMETER FilePath
        The full path to the file to test.

    .EXAMPLE
        Test-FileContainsClassResource -FilePath 'c:\mymodule\myclassmodule.psm1'

        This command will test myclassmodule.psm1 for the presence of any class-based
        DSC resources, including those with attributes like [DscResource()] or
        [DscResource(RunAsCredential = 'Optional')].
#>
function Test-FileContainsClassResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]
        $FilePath
    )

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref] $null, [ref] $null)

    # Look for class/type definitions that have a [DscResource(...)] attribute
    $typeDefinitionAsts = $fileAst.FindAll({
        param($ast)
        $ast -is [System.Management.Automation.Language.TypeDefinitionAst]
    }, $true)

    foreach ($typeDefinitionAst in $typeDefinitionAsts)
    {
        foreach ($attributeAst in $typeDefinitionAst.Attributes)
        {
            # Prefer the simple name, fall back to FullName if needed
            $attributeName = $attributeAst.TypeName.Name

            if ([string]::IsNullOrEmpty($attributeName))
            {
                $attributeName = $attributeAst.TypeName.FullName
            }

            if ($attributeName -eq 'DscResource')
            {
                # Return on first hit.
                return $true
            }
        }
    }

    return $false
}
