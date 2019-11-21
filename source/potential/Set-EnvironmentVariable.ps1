<#
    .SYNOPSIS
        This command will set the machine and session environment variable to
        a value.

    .PARAMETER Name
        The name of the variable to set.

    .PARAMETER Value
        The value of the variable to set. If this is set to $null or
        empty string ('') the environment variable will be removed.

    .PARAMETER Machine
        If present, the environment variable will be set machine wide.
        If not present, the environment variable will be set for the user.
#>
function Set-EnvironmentVariable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [System.String]
        $Value,

        [Parameter()]
        [Switch]
        $Machine
    )

    if ($Machine.IsPresent)
    {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
        Set-Item -Path "env:\$Name" -Value $Value
    }
    else
    {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Set-Item -Path "env:\$Name" -Value $Value
    }
}