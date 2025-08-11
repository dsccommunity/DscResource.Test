<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'JeaDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/ModuleManifest.common.*.Tests.ps1" -Data @{
            ModuleName = $dscResourceModuleName
            ModuleBase = "./output/builtModule/$dscResourceModuleName/*"
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleName,

    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPesterMinimum5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1 or higher.
if (-not $isPesterMinimum5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester v5 and v6 are skipped.' -Verbose
    return
}

<#
    This _must_ be outside any Pester blocks for correct script parsing.
    Sets Context block's default parameter value to handle Pester v6's ForEach
    change, to keep same behavior as with Pester v5. The default parameter is
    removed at the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true
$PSDefaultParameterValues['It:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    <#
        Make sure relative path with wildcard are resolved to version folder,
        e.g. ./output/builtModule/ModuleName/* -> ./output/builtModule/ModuleName/1.0.0
    #>
    $resolvedModuleBase = Resolve-Path -Path $ModuleBase -ErrorAction 'Stop'

    # Check if module contains class-based resources for DSCv2 compatibility tests
    $hasClassBasedResources = Test-ModuleContainsClassResource -ModulePath $resolvedModuleBase

    if ($hasClassBasedResources)
    {
        $moduleFiles = Get-ChildItem -Path $resolvedModuleBase -Filter '*.psm1' -Recurse

        $classResourcesInModule = foreach ($moduleFile in $moduleFiles)
        {
            Get-ClassResourceNameFromFile -FilePath $moduleFile.FullName
        }

        #region Setup text file test cases.
        $classBasedResource = foreach ($resourceName in $classResourcesInModule)
        {
            @{
                Name = $resourceName
            }
        }
    }
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - Module Manifest' -Tag 'Common Tests - Module Manifest' {
    BeforeAll {
        $moduleManifestPath = Join-Path -Path $ModuleBase -ChildPath "$ModuleName.psd1"

        $script:moduleManifestProperties = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction 'Stop'
    }

    It 'Should have valid module manifest' {
        $moduleManifest = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'

        $moduleManifest | Should -Not -BeNullOrEmpty
    }

    It 'Should contain a PowerShellVersion property with a minimum value based on resource types' {
        $containsClassResource = Test-ModuleContainsClassResource -ModulePath $ModuleBase

        if ($containsClassResource)
        {
            $minimumPSVersion = [Version] '5.0'
        }
        else
        {
            $minimumPSVersion = [Version] '4.0'
        }

        $script:moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should -BeTrue -Because ('the test evaluated that the minimum version should be ''{0}''' -f $minimumPSVersion)
    }

    Context 'When class-based resources exist' -Skip:(-not $hasClassBasedResources) {
        BeforeDiscovery {
            $moduleManifestPath = Join-Path -Path $ModuleBase -ChildPath "$ModuleName.psd1"
            $rawModuleManifest = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction 'Stop'
            $cmdletsToExportExists = $rawModuleManifest.ContainsKey('CmdletsToExport')
        }

        It 'Should explicitly export <Name> in DscResourcesToExport'  -ForEach $classBasedResource {
            $script:moduleManifestProperties.DscResourcesToExport | Should -Contain $Name
        }

        # Using -ForEach to bring in the value from Discovery-phase to avoid reading Module Manifest a second time.
        It 'Should have CmdletsToExport set to ''*'' for compatibility with DSCv2' -Skip:(-not $cmdletsToExportExists) -ForEach @($rawModuleManifest) {
            $cmdletsToExport = $_.CmdletsToExport

            $cmdletsToExport | Should -Be '*' -Because 'when CmdletsToExport is present in a module with class-based resources, it must be set to ''*'' for compatibility with PSDesiredStateConfiguration 2.0.7'
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
$PSDefaultParameterValues.Remove('It:AllowNullOrEmptyForEach')
