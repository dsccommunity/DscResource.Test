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

Describe 'Common Tests - File Formatting' -Tag 'Common Tests - File Formatting'  {
    $textFiles = @(Get-TextFilesList -Root $ModuleBase | WhereModuleFileNotExcluded)

    if ($SourcePath)
    {
        $textFiles += Get-TextFilesList -Root $SourcePath | WhereSourceFileNotExcluded
    }

    It 'Should not contain any files with Unicode file encoding' {
        $containsUnicodeFile = $false

        foreach ($textFile in $textFiles)
        {
            if (Test-FileInUnicode -FileInfo $textFile)
            {
                if ($textFile.Extension -ieq '.mof')
                {
                    Write-Warning -Message "File $($textFile.FullName) should be converted to ASCII. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-ASCII'."
                }
                else
                {
                    Write-Warning -Message "File $($textFile.FullName) should be converted to UTF-8. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
                }

                $containsUnicodeFile = $true
            }
        }

        $containsUnicodeFile | Should -BeFalse
    }

    It 'Should not contain any files with tab characters' {
        $containsFileWithTab = $false

        foreach ($textFile in $textFiles)
        {
            $fileName = $textFile.FullName
            $fileContent = Get-Content -Path $fileName -Raw

            $tabCharacterMatches = $fileContent | Select-String -Pattern "`t"

            if ($null -ne $tabCharacterMatches)
            {
                Write-Warning -Message "Found tab character(s) in $fileName."
                $containsFileWithTab = $true
            }
        }

        $containsFileWithTab | Should -BeFalse
    }

    It 'Should not contain empty files' {
        $containsEmptyFile = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if ([String]::IsNullOrWhiteSpace($fileContent))
            {
                Write-Warning -Message "File $($textFile.FullName) is empty. Please remove this file."
                $containsEmptyFile = $true
            }
        }

        $containsEmptyFile | Should -BeFalse
    }

    It 'Should not contain files without a newline at the end' {
        $containsFileWithoutNewLine = $false

        foreach ($textFile in $textFiles)
        {
            $fileContent = Get-Content -Path $textFile.FullName -Raw

            if (-not [String]::IsNullOrWhiteSpace($fileContent) -and $fileContent[-1] -ne "`n")
            {
                if (-not $containsFileWithoutNewLine)
                {
                    Write-Warning -Message 'Each file must end with a new line.'
                }

                Write-Warning -Message "$($textFile.FullName) does not end with a new line. Use fixer function 'Add-NewLine'"

                $containsFileWithoutNewLine = $true
            }
        }

        $containsFileWithoutNewLine | Should -BeFalse
    }

    Context 'When repository contains markdown files' {
        $markdownFileExtensions = @('.md')

        $markdownFiles = $textFiles |
            Where-Object -FilterScript { $markdownFileExtensions -contains $_.Extension }

        foreach ($markdownFile in $markdownFiles)
        {
            $filePathOutputName = Get-RelativePathFromModuleRoot `
                -FilePath $markdownFile.FullName `
                -ModuleRootFilePath $ModuleBase

            It ('Markdown file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $markdownFileHasBom = Test-FileHasByteOrderMark -FilePath $markdownFile.FullName

                if ($markdownFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $markdownFileHasBom | Should -BeFalse
            }
        }
    }
}
