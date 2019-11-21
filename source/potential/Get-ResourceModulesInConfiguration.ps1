
<#
    .SYNOPSIS
        Gets an array of DSC Resource modules imported in a DSC Configuration
        file.

    .PARAMETER ConfigurationPath
        The path to the configuration file to get the list from.
#>
function Get-ResourceModulesInConfiguration
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ConfigurationPath
    )

    # Resource modules
    $listedModules = @()

    # Get the AST object for the configuration
    $dscConfigurationAST = [System.Management.Automation.Language.Parser]::ParseFile($ConfigurationPath , [ref]$null, [ref]$Null)

    # Get all the Import-DscResource module commands
    $findAllImportDscResources = {
        $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] `
            -and $args[0].CommandElements[0].Value -eq 'Import-DscResource'
    }

    $importDscResourceCmds = $dscConfigurationAST.EndBlock.FindAll( $findAllImportDscResources, $true )

    foreach ($importDscResourceCmd in $importDscResourceCmds)
    {
        $parameterName = 'ModuleName'
        $moduleName = ''
        $moduleVersion = ''

        foreach ($element in $importDscResourceCmd.CommandElements)
        {
            # For each element in the Import-DscResource command determine what it means
            if ($element -is [System.Management.Automation.Language.CommandParameterAst])
            {
                $parameterName = $element.ParameterName
            }
            elseif ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] `
                    -and $element.Value -ne 'Import-DscResource')
            {
                switch ($parameterName)
                {
                    'ModuleName'
                    {
                        $moduleName = $element.Value
                    } # ModuleName

                    'ModuleVersion'
                    {
                        $moduleVersion = $element.Value
                    } # ModuleVersion
                } # switch
            }
            elseif ($element -is [System.Management.Automation.Language.ArrayLiteralAst])
            {
                <#
                    This is an array of strings (usually something like xNetworking,xWebAdministration)
                    So we need to add each module to the list
                #>
                foreach ($item in $element.Elements)
                {
                    $listedModules += @{
                        Name = $item.Value
                    }
                } # foreach
            } # if
        } # foreach

        # Did a module get identified when stepping through the elements?
        if (-not [String]::IsNullOrEmpty($moduleName))
        {
            if ([String]::IsNullOrEmpty($moduleVersion))
            {
                $listedModules += @{
                    Name = $moduleName
                }
            }
            else
            {
                $listedModules += @{
                    Name    = $moduleName
                    Version = $moduleVersion
                }
            }
        } # if
    } # foreach

    return $listedModules
}
