[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param
(
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourcePath,
    $SourceManifest,
    $Tag,
    $ExcludeTag,
    $ExcludeModuleFile,
    $ExcludeSourceFile
)

Describe 'Common Tests - Module Manifest' -Tag 'Common Tests - Module Manifest' {
    $containsClassResource = Test-ModuleContainsClassResource -ModulePath $ModuleBase

    if ($containsClassResource)
    {
        $minimumPSVersion = [Version] '5.0'
    }
    else
    {
        $minimumPSVersion = [Version] '4.0'
    }

    $moduleManifestPath = Join-Path -Path $ModuleBase -ChildPath "$moduleName.psd1"

    <#
        ErrorAction specified as SilentlyContinue because this call will throw an error
        on machines with an older PS version than the manifest requires. WMF 5.1 machines
        are not yet available on AppVeyor, so modules that require 5.1 (PSDscResources)
        would always crash this test.
    #>
    $moduleManifestProperties = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'

    It "Should contain a PowerShellVersion property of at least $minimumPSVersion based on resource types" {
        $moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should -BeTrue
    }

    if ($containsClassResource)
    {
        $classResourcesInModule = Get-ClassResourceNameFromFile -FilePath $moduleRootFilePath

        Context 'Requirements for manifest of module with class-based resources' {
            foreach ($classResourceInModule in $classResourcesInModule)
            {
                It "Should explicitly export $classResourceInModule in DscResourcesToExport" {
                    $moduleManifestProperties.ExportedDscResources -contains $classResourceInModule | Should -BeTrue
                }

                It "Should include class module $classResourceInModule.psm1 in NestedModules" {
                    $moduleManifestProperties.NestedModules.Name -contains $classResourceInModule | Should -BeTrue
                }
            }
        }
    }
}
