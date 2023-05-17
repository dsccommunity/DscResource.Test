
<#
    .SYNOPSIS
        Concatenates two string that contain semi-colon separated strings.

    .PARAMETER Path
        A string with all the paths separated by semi-colons.

    .PARAMETER NewPath
        A string with all the paths separated by semi-colons.

    .EXAMPLE
        Join-PSModulePath -Path '<Path 1>;<Path 2>' -NewPath 'Path3;Path4'
#>
function Join-PSModulePath
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NewPath
    )

    foreach ($currentNewPath in ($NewPath -split ';'))
    {
        if ($Path -cnotmatch [System.Text.RegularExpressions.Regex]::Escape($currentNewPath))
        {
            $Path = @($Path, $currentNewPath) -join ';'
        }
    }

    return $Path
}
