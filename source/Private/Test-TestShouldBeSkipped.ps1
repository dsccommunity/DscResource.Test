function Test-TestShouldBeSkipped
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $TestNames,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [System.String[]]
        $Tag,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [System.String[]]
        $ExcludeTag
    )

    if ($ExcludeTag)
    {
        $IsTagExcluded = Compare-Object -ReferenceObject $TestNames -DifferenceObject $ExcludeTag -IncludeEqual -ExcludeDifferent
    }
    else
    {
        $IsTagExcluded = $false
    }

    $IsTagIncluded = Compare-Object -ReferenceObject $TestNames -DifferenceObject $Tag -IncludeEqual -ExcludeDifferent

    # Should be skipped if It's excluded or Tags are in use and it's not included
    $ShouldBeSkipped = ($IsTagExcluded -or ($Tag -and -Not $isTagIncluded))

    if ($ShouldBeSkipped)
    {
        Write-Warning "The tests for $($TestNames -join ',') is not being enforced. Please Opt-in!"
    }

    return $ShouldBeSkipped
}
