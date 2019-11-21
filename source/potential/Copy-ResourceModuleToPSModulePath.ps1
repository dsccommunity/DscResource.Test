<#
    .SYNOPSIS
        Copies the resource module to the PowerShell module path.

    .PARAMETER ResourceModuleName
        Name of the resource module being deployed.

    .PARAMETER ModuleRootPath
        The root path to the repository.

    .OUTPUTS
        Returns the path to where the module was copied (the root of the module).
#>
function Copy-ResourceModuleToPSModulePath
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleRootPath
    )

    $psHomePSModulePathItem = Get-PSHomePSModulePathItem
    $powershellModulePath = Join-Path -Path $psHomePSModulePathItem -ChildPath $ResourceModuleName

    Write-Verbose -Message ('Copying module from ''{0}'' to ''{1}''' -f $ModuleRootPath, $powershellModulePath)

    # Creates the destination module folder.
    New-Item -Path $powershellModulePath -ItemType Directory -Force | Out-Null

    # Copies all module files into the destination module folder.
    Copy-Item -Path (Join-Path -Path $ModuleRootPath -ChildPath '*') `
        -Destination $powershellModulePath `
        -Exclude @('node_modules', '.*') `
        -Recurse `
        -Force

    return $powershellModulePath
}