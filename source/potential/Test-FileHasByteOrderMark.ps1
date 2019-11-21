
<#
    .SYNOPSIS
        Tests if a file contains Byte Order Mark (BOM).

    .PARAMETER FilePath
        The file path to evaluate.
#>
function Test-FileHasByteOrderMark
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FilePath
    )

    $getContentParameters = @{
        Path       = $FilePath
        ReadCount  = 3
        TotalCount = 3
    }

    # Need to treat Windows Powershell and PowerShell Core different.
    if ($PSVersionTable.PSEdition -eq 'Core')
    {
        $getContentParameters['AsByteStream'] = $true
    }
    else
    {
        $getContentParameters['Encoding'] = 'Byte'
    }

    # This reads the first three bytes of the first row.
    $firstThreeBytes = Get-Content @getContentParameters

    # Check for the correct byte order (239,187,191) which equal the Byte Order Mark (BOM).
    return ($firstThreeBytes[0] -eq 239 `
            -and $firstThreeBytes[1] -eq 187 `
            -and $firstThreeBytes[2] -eq 191)
}
