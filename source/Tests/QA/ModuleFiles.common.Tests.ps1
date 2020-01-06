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

Describe 'Common Tests - Validate Module Files' -Tag @('Module','Common Tests - Validate Module Files') {
    $moduleFiles = @(Get-Psm1FileList -FilePath $ModuleBase | WhereModuleFileNotExcluded)

    if ($SourcePath)
    {
        $moduleFiles += Get-Psm1FileList -FilePath $SourcePath | WhereSourceFileNotExcluded
    }

    foreach ($moduleFile in $moduleFiles)
    {
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $moduleFile.FullName `
            -ModuleRootFilePath $ModuleBase

        Context $filePathOutputName {
            It ('Module file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $moduleFileHasBom = Test-FileHasByteOrderMark -FilePath $moduleFile.FullName

                if ($moduleFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $moduleFileHasBom | Should -BeFalse
            }
        }
    }
}
