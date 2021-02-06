<#
    .SYNOPSIS
        This command will return a container for each available HQRM test script.

    .EXAMPLE
        $getDscResourceTestContainersParameters = @{
            ProjectPath       = '.'
            ModuleName        = 'MyDscResourceName'
            DefaultBranch     = 'main'
            SourcePath        = './source'
            ExcludeSourceFile = @('Examples')
            ModuleBase        = "./output/MyDscResourceName/*"
            ExcludeModuleFile = @('Modules/DscResource.Common')
        }

        $container = Get-DscResourceTestContainers @getDscResourceTestContainersParameters

        Invoke-Pester -Container $container -Output Detailed

        Returns a container for each available HQRM test script using the provided
        values as script parameters. Then Pester is invoked on the containers.
#>
function Get-DscResourceTestContainers
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ProjectPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DefaultBranch,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SourcePath,

        [Parameter()]
        [System.String[]]
        $ExcludeSourceFile,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleBase,

        [Parameter()]
        [System.String[]]
        $ExcludeModuleFile
    )

    $pesterVersion = (Get-Module -Name 'Pester' -ListAvailable).Version
    $availablePesterVersion = ($pesterVersion | Measure-Object -Maximum).Maximum

    if ($availablePesterVersion -lt '5.1.0')
    {
        throw 'This command requires Pester v5.1.0 or higher to be installed.'
    }


    $hqrmTests = Join-Path -Path $PSScriptRoot -ChildPath 'Tests/QA/*.common.v5.Tests.ps1'

    $containerData = @{
        MainGitBranch     = $DefaultBranch
        ProjectPath       = $ProjectPath
        ModuleName        = $ModuleName
        ModuleBase        = $ModuleBase
        SourcePath        = $SourcePath
        ExcludeModuleFile = $ExcludeModuleFile
        ExcludeSourceFile = $ExcludeSourceFile
    }

    $container = New-PesterContainer -Path $hqrmTests -Data $containerData

    return $container
}
