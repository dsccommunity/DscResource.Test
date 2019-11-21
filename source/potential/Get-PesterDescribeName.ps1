<#
    .SYNOPSIS
        Gets the current Pester Describe block name
#>
function Get-PesterDescribeName
{

    return Get-CommandNameParameterValue -Command 'Describe'
}