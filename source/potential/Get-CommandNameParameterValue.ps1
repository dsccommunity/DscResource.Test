
<#
    .SYNOPSIS
        Gets the value of the Name parameter for the specified command in the stack.

    .PARAMETER Command
        The name of the command to find the Name parameter for.
#>
function Get-CommandNameParameterValue
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Command
    )

    $commandStackItem = (Get-PSCallStack).Where{ $_.Command -eq $Command }
    $commandArgumentNameValues = $commandStackItem.Arguments.TrimStart('{', ' ').TrimEnd('}', ' ') -split '\s*,\s*'
    $nameParameterValue = ($commandArgumentNameValues.Where{ $_ -like 'name=*' } -split '=')[-1]
    return $nameParameterValue
}