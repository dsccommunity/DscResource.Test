function Test-ConfigurationName
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    <#
        Resource modules using auto-documentation uses a numeric value followed by a dash ('-') to be able to control
        the order of the example in the documentation. That will not be used when publishing, so remove it here from
        the name that is compared to the configuration name.
    #>
    $publishFilename = (Get-Item -Path $Path).BaseName -replace '^[0-9]+-'

    $parseErrors = $null
    $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $null, [ref] $parseErrors)

    if ($parseErrors)
    {
        throw $parseErrors
    }

    $astFilter = {
        $args[0] -is [System.Management.Automation.Language.ConfigurationDefinitionAst]
    }

    $configurationDefinition = $definitionAst.Find($astFilter, $true)

    $isOfCorrectType = $configurationDefinition.ConfigurationType -in @(
        [System.Management.Automation.Language.ConfigurationType]::Resource
        [System.Management.Automation.Language.ConfigurationType]::Meta
    )

    $configurationName = $configurationDefinition.InstanceName.Value
    $hasEqualName = $configurationName -eq $publishFilename

    <#
        The name can contain only letters, numbers, and underscores.
        The name must start with a letter, and it must end with a letter or a number.
    #>
    $hasCorrectNamingConvention = $configurationName -match '^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$'

    if ($isOfCorrectType -and $hasEqualName -and $hasCorrectNamingConvention)
    {
        $result = $true
    }
    else
    {
        $result = $false
    }

    return $result
}
