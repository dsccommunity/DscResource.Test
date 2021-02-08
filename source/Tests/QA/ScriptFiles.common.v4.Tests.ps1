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

Describe 'Common Tests - Validate Script Files' -Tag 'Script','Common Tests - Validate Script Files' {
    $scriptFiles = @(Get-ChildItem $ModuleBase -Recurse -Include *.ps1 | WhereModuleFileNotExcluded).ForEach{
        $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $ModuleBase -PassThru
    }

    if ($SourcePath)
    {
        $scriptFiles += @(Get-ChildItem $SourcePath -Recurse -Include *.ps1 | WhereSourceFileNotExcluded).ForEach{
            $_ | Add-Member -NotePropertyName ModuleBase -NotePropertyValue $SourcePath -PassThru
        }
    }

    Write-Debug -Message "Processing $($scriptFiles.Count) files..."

    foreach ($scriptFile in $scriptFiles)
    {
        Write-Debug -Message "... $scriptFile"

        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $scriptFile.FullName `
            -ModuleRootFilePath $scriptFile.ModuleBase

        Context $filePathOutputName {
            It ('Script file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $scriptFile.FullName

                if ($scriptFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $scriptFileHasBom | Should -BeFalse -Because "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
            }
        }
    }
}
