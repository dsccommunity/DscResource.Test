[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param (
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

Describe 'Common Tests - Relative Path Length' -Tag 'Common Tests - Relative Path Length' {

    Context -Name 'When the resource should be used to compile a configuration in Azure Automation' {
        <#
            129 characters is the current maximum for a relative path to be
            able to compile configurations in Azure Automation.
        #>
        $fullPathHardLimit = 129
        $allModuleFiles = (Get-ChildItem -Path $ModuleBase -Recurse | WhereModuleFileNotExcluded).Foreach{
            $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $ModuleBase -PassThru
        }

        if ($SourcePath)
        {
            $allModuleFiles += @(Get-ChildItem -Path $SourcePath -Recurse | WhereSourceFileNotExcluded).Foreach{
                $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $SourcePath -PassThru
            }
        }

        $testCaseModuleFile = @()

        $allModuleFiles | ForEach-Object -Process {
            $testCaseModuleFile += @(
                @{
                    FullRelativePath = Get-RelativePathFromModuleRoot -FilePath $_.FullName -ModuleRootFilePath $_.ModuleBase
                }
            )
        }

        It 'The length of the relative full path <FullRelativePath> should not exceed the max hard limit' -TestCases $testCaseModuleFile {
            param
            (
                [Parameter()]
                [System.String]
                $FullRelativePath
            )

            $FullRelativePath.Length | Should -Not -BeGreaterThan $fullPathHardLimit
        }
    }
}
