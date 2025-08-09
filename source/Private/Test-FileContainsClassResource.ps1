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

    $tokens = $null
    $parseErrors = $null
    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref] $tokens, [ref] $parseErrors)
    
    # Check for parsing errors and throw exception for the first error that's not a DSC validation error
    if ($parseErrors -and $parseErrors.Count -gt 0)
    {
        $syntaxErrors = $parseErrors | Where-Object { $_.ErrorId -notlike 'DscResource*' }
        if ($syntaxErrors -and $syntaxErrors.Count -gt 0)
        {
            $firstError = $syntaxErrors[0]
            throw "Parse error in file '$FilePath': $($firstError.Message) at line $($firstError.Extent.StartLineNumber), column $($firstError.Extent.StartColumnNumber)"
        }
    }

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
