<#
    .SYNOPSIS
        Returns an invalid operation exception object.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating
        error.
#>
function Get-InvalidOperationRecord
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

    $PSBoundParameters.Add('ExceptionType', 'System.InvalidOperationException')

    return Get-SystemExceptionRecord @PSBoundParameters
}
