
<#
    .SYNOPSIS
        Gets the opt-in status of an option with the specified name. Writes
        a warning if the test is not opted-in.

    .PARAMETER OptIns
        An array of what is opted-in.

    .PARAMETER Name
        The name of the opt-in option to check the status of.
#>
function Get-OptInStatus
{
    param
    (
        [Parameter()]
        [System.String[]]
        $OptIns,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $optIn = $OptIns -icontains $Name
    if (-not $optIn)
    {
        $message = @"
$Name will not fail unless you opt-in.
To opt-in, create a '.MetaTestOptIn.json' at the root
of the repo in the following format:
[
     "$Name"
]
"@
        Write-Warning -Message $message
    }

    return $optIn
}