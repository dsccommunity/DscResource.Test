<#
    .SYNOPSIS
        Returns an object not found exception object.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating
        error.
#>
function Get-ObjectNotFoundRecord
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    $null = $PSBoundParameters.Add('ExceptionType', 'System.Exception')

    return Get-SystemExceptionRecord @PSBoundParameters
}
