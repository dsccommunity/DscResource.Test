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

Describe 'Common Tests - .psm1 File Parsing' -Tag 'Common Tests - .psm1 File Parsing' {
    $psm1Files = @(Get-Psm1FileList -FilePath $ModuleBase | WhereModuleFileNotExcluded)

    if ($SourcePath)
    {
        $psm1Files += Get-Psm1FileList -FilePath $SourcePath | WhereSourceFileNotExcluded
    }

    foreach ($psm1File in $psm1Files)
    {
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $psm1File.FullName `
            -ModuleRootFilePath $ModuleBase

        Context $filePathOutputName {
            It ('Module file ''{0}'' should not contain parse errors' -f $filePathOutputName) {
                $containsParseErrors = $false

                $parseErrors = Get-FileParseError -FilePath $psm1File.FullName

                if ($null -ne $parseErrors)
                {
                    Write-Warning -Message "There are parse errors in $($psm1File.FullName):"
                    Write-Warning -Message ($parseErrors | Format-List | Out-String)

                    $containsParseErrors = $true
                }

                $containsParseErrors | Should -BeFalse
            }
        }
    }
}
