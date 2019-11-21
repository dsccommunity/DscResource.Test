
<#
    .SYNOPSIS
        Returns first the item in $env:PSModulePath that matches the given Prefix ($env:PSModulePath is list of semicolon-separated items).
        If no items are found, it reports an error.
    .PARAMETER Prefix
        Path prefix to look for.
    .NOTES
        If there are multiple matching items, the function returns the first item that occurs in the module path; this matches the lookup
        behavior of PowerSHell, which looks at the items in the module path in order of occurrence.
    .EXAMPLE
        If $env:PSModulePath is
            C:\Program Files\WindowsPowerShell\Modules;C:\Users\foo\Documents\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules
        then
            Get-PSModulePathItem C:\Users
        will return
            C:\Users\foo\Documents\WindowsPowerShell\Modules
#>
function Get-PSModulePathItem
{
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Prefix
    )

    $item = $env:PSModulePath.Split(';') |
        Where-Object -FilterScript { $_ -like "$Prefix*" } |
        Select-Object -First 1

    if (-not $item)
    {
        Write-Error -Message "Cannot find the requested item in the PowerShell module path.`n`$env:PSModulePath = $env:PSModulePath"
    }
    else
    {
        $item = $item.TrimEnd('\')
    }

    return $item
}
