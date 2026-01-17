<#
    .SYNOPSIS
        Returns the Localized Keys from an instance of a class.

    .PARAMETER File
        The FileInfo object for the module file.

    .PARAMETER ClassName
        The name of the class to get the Localized Keys from.
#>

function Get-ClassInstanceLocalizedKeys
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param (
        [Parameter()]
        [System.IO.FileInfo]
        $File,

        [Parameter()]
        [System.String]
        $ClassName
    )

    # Import module by full path and get the ModuleInfo object so
    # we can access the implementing assembly even when the module
    # is in a non-standard location.
    $mod = Import-Module -Name $File.FullName -Force -PassThru

    if (-not $mod -or -not $mod.ImplementingAssembly)
    {
        return
    }

    $current = $mod.ImplementingAssembly.DefinedTypes.Where(
        { $_.Name -eq $ClassName -and
            $_.IsPublic -and
            $_.BaseType.FullName -ne 'System.Object'
        }).FullName

    if ($current)
    {
        # Try to get the parent type from the same assembly first,
        # fallback to GetType if necessary.
        $currentClass = $mod.ImplementingAssembly.GetType($current)
        if (-not $currentClass)
        {
            $currentClass = [System.Type]::GetType($current)
        }

        if ($currentClass)
        {
            try
            {
                # Do not let PowerShell auto-unroll the array
                return , @($currentClass::new().LocalizedData.Keys)
            }
            catch
            {
                return
            }
        }
    }

    return
}
