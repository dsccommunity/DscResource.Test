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

    $newObjectParameters = @{
        TypeName = 'System.InvalidOperationException'
    }

    if ($PSBoundParameters.ContainsKey('Message') -and $PSBoundParameters.ContainsKey('ErrorRecord'))
    {
        $newObjectParameters['ArgumentList'] = @(
            $Message,
            $ErrorRecord.Exception
        )
    }
    elseif ($PSBoundParameters.ContainsKey('Message'))
    {
        $newObjectParameters['ArgumentList'] = @(
            $Message
        )
    }

    $invalidOperationException = New-Object @newObjectParameters

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'InvalidOperation',
            $null
        )
    }

    return New-Object @newObjectParameters
}
