<#
    .SYNOPSIS
        Tests if a PowerShell file contains a DSC class resource.

    .PARAMETER FilePath
        The full path to the file to test.

    .EXAMPLE
        Test-ContainsClassResource -ModulePath 'c:\mymodule\myclassmodule.psm1'

        This command will test myclassmodule for the presence of any class-based
        DSC resources.
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

    $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)

    foreach ($fileAttributeAst in $fileAst.FindAll( {$args[0] -is [System.Management.Automation.Language.AttributeAst]}, $false))
    {
        if ($fileAttributeAst.Extent.Text -ieq '[DscResource()]' -or $fileAttributeAst.Extent.Text -ilike '`[DscProperty(*')
        {
            return $true
        }
    }

    return $false
}
