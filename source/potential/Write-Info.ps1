
<#
    .SYNOPSIS
        Writes a message to the console in a standard format.

    .PARAMETER Message
        The message to write to the console.

    .PARAMETER ForegroundColor
        The text color to use when writing the message to the console. Defaults
        to 'Yellow'.
#>
function Write-Info
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message,

        [Parameter()]
        [System.String]
        $ForegroundColor = 'Yellow'
    )

    Write-Host -ForegroundColor $ForegroundColor -Object "[Build Info] [UTC $([System.DateTime]::UtcNow)] $message"
}
