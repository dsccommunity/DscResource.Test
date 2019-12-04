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

Describe 'Common Tests - Validate Script Files' -Tag 'Script','Common Tests - Validate Script Files' {

    $AddModuleBaseParam = @{
        NotePropertyName = 'ModuleBase'

    }

    $scriptFiles = @(Get-ChildItem $ModuleBase -Recurse -Include *.ps1 | WhereModuleFileNotExcluded).Foreach{
        $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $ModuleBase -PassThru
    }

    if ($SourcePath)
    {
        $scriptFiles += @(Get-ChildItem $SourcePath -Recurse -Include *.ps1 | WhereSourceFileNotExcluded).Foreach{
            $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $SourcePath -PassThru
        }
    }

    Write-Debug -Message "Processing $($scriptFiles.Count) files..."

    foreach ($scriptFile in $scriptFiles)
    {
        Write-Debug -Message "... $scriptFile"
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $scriptFile.FullName `
            -ModuleRootFilePath $_.ModuleBase

        Context $filePathOutputName {
            It ('Script file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $scriptFile.FullName

                if ($scriptFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $scriptFileHasBom | Should -Be $false -Because "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
            }
        }
    }
}
