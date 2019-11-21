function ConvertTo-OrderedDictionary
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding()]
    [outputType([System.Object])]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [Object]
        $InputObject
    )

    if ($null -eq $InputObject)
    {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $hashKeys = $InputObject.Keys
        # Making the Ordered Dict Case Insensitive
        $result = [ordered]@{ }
        foreach ($Key in $hashKeys)
        {
            $result[$Key] = ConvertTo-OrderedDictionary -InputObject $InputObject[$Key]
        }
        $result
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isNot [string])
    {
        $collection = @(
            foreach ($object in $InputObject)
            {
                ConvertTo-OrderedDictionary -InputObject $object
            }
        )

        , $collection
    }
    elseif ($InputObject -is [PSCustomObject])
    {
        $result = [ordered]@{ }
        foreach ($property in $InputObject.PSObject.Properties)
        {
            $result[$property.Name] = ConvertTo-OrderedDictionary -InputObject $property.Value
        }

        $result
    }
    else
    {
        $InputObject
    }
}
