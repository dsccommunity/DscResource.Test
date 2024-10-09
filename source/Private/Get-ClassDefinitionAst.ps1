<#
    .SYNOPSIS
        Returns the class definition ASTs for a script file.

    .PARAMETER FullName
        Full path to the script file.
#>
function Get-ClassDefinitionAst
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FullName
    )

    $tokens, $parseErrors = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $FullName,
        [ref] $tokens,
        [ref] $parseErrors
    )

    if ($parseErrors)
    {
        throw $parseErrors
    }

    $astFilter = {
        param
        (
            [Parameter()]
            [System.Management.Automation.Language.Ast]
            $Ast
        )

        $Ast -is [System.Management.Automation.Language.TypeDefinitionAst]
    }

    return $ast.FindAll($astFilter, $true)
}
