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
    $ExcludeSourceFile,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

$isPester5 = (Get-Module -Name Pester).Version -lt '5.0.0'

# Only run if _not_ Pester 5.
if (-not $isPester5)
{
    return
}

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
        $moduleFiles = Get-ChildItem -Path $ModuleBase -Filter *.psm1 -Recurse
        $classResourcesInModule = foreach ($moduleFile in $moduleFiles)
        {
            Get-ClassResourceNameFromFile -FilePath $moduleFile.FullName
        }

        Context 'Requirements for manifest of module with class-based resources' {
            foreach ($classResourceInModule in $classResourcesInModule)
            {
                It "Should explicitly export $classResourceInModule in DscResourcesToExport" {
                    $moduleManifestProperties.ExportedDscResources -contains $classResourceInModule | Should -BeTrue
                }
            }
        }
    }
}
