function Get-DscResourceTestConfiguration
{
    [cmdletBinding()]
    param
    (
        [Parameter()]
        [Alias('Path')]
        [Object]
        $Configuration = (Join-Path $PWD '.MetaTestOptIn.json')
    )

    if ($Configuration -is [System.Collections.IDictionary])
    {
        Write-Debug "Configuration Object is a Dictionary"
    }
    elseif ($Configuration -is [System.Management.Automation.PSCustomObject])
    {
        Write-Debug "Configuration Object is a PSCustomObject"
    }
    elseif ( $Configuration -is [System.String])
    {
        Write-Debug "Configuration Object is a String, probably a Path"
        $Configuration = Get-StructuredObjectFromFile -Path $Configuration
    }
    else
    {
        throw "Could not resolve Configuration parameter $Configuration of Type $($Configuration.GetType().ToString())"
    }

    $NormalizedConfigurationObject = ConvertTo-OrderedDictionary -InputObject $Configuration

    return $NormalizedConfigurationObject
}
