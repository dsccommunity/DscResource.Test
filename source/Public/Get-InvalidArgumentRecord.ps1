<#
    .SYNOPSIS
        Returns an invalid argument exception object

    .PARAMETER Message
        The message explaining why this error is being thrown

    .PARAMETER ArgumentName
        The name of the invalid argument that is causing this error to be thrown
#>
function Get-InvalidArgumentRecord
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'System.ArgumentException' -ArgumentList @( $Message, $ArgumentName )

    $newObjectParams = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @( $argumentException, $ArgumentName, 'InvalidArgument', $null )
    }

    return New-Object @newObjectParams
}
