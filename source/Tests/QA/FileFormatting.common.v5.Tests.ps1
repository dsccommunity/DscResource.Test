<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/FileFormatting.common.*.Tests.ps1" -Data @{
            SourcePath = './source'
            ModuleBase = "./output/$dscResourceModuleName/*"
            # ExcludeModuleFile = @('Modules/DscResource.Common')
            # ExcludeSourceFile = @('Examples')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '')]
param
(
    $ModuleBase,
    $SourcePath,
    $ExcludeModuleFile,
    $ExcludeSourceFile,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPester5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1.
if (-not $isPester5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester 5 are skipped.' -Verbose
    return
}

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    $textFiles = @(Get-TextFilesList -Root $ModuleBase | WhereModuleFileNotExcluded -ExcludeModuleFile $ExcludeModuleFile)

    if ($SourcePath)
    {
        $textFiles += Get-TextFilesList -Root $SourcePath | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile
    }

    # Get the root of the source folder.
    $resolvedSourcePath = (Resolve-Path -Path $SourcePath).Path
    $resolvedSourcePath = Split-Path -Path $resolvedSourcePath -Parent

    #region Setup text file test cases.
    $textFileToTest = @()

    foreach ($file in $textFiles)
    {
        # Use the root of the source folder to extrapolate relative path.
        $descriptiveName = Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedSourcePath

        $textFileToTest += @(
            @{
                File = $file
                DescriptiveName = $descriptiveName
            }
        )
    }
    #endregion

    #region Setup markdown file test cases.
    $markdownFileExtensions = @('.md')

    $markdownFiles = $textFiles |
        Where-Object -FilterScript { $_.Extension -contains $markdownFileExtensions }

    $markdownFileToTest = @()

    foreach ($file in $markdownFiles)
    {
        # Use the root of the source folder to extrapolate relative path.
        $descriptiveName = Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedSourcePath

        $markdownFileToTest += @(
            @{
                File = $file
                DescriptiveName = $descriptiveName
            }
        )
    }
    #endregion
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module 'DscResource.Test' -Force
}

Describe 'Common Tests - File Formatting' -Tag 'Common Tests - File Formatting'  {
    Context 'When code file ''<DescriptiveName>'' exist' -ForEach $textFileToTest {
        BeforeEach {
            <#
                TODO: This should be updated when issue https://github.com/dsccommunity/DscResource.Test/issues/92
                is resolved.
            #>
            if ($File.Extension -ieq '.mof')
            {
                $becauseMessage = "File $($File.FullName) should be converted to ASCII. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-ASCII'."
            }
            else
            {
                $becauseMessage = "File $($textFile.FullName) should be converted to UTF-8. Use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
            }

            $script:fileContent = Get-Content -Path $File.FullName -Raw
        }

        It 'Should not contain a unicode file encoding' {
            Test-FileInUnicode -FileInfo $File | Should -BeFalse -Because $becauseMessage
        }

        It 'Should not contain any tab characters' {
            $tabCharacterMatches = $script:fileContent | Select-String -Pattern "`t"

            $containsFileWithTab = $null -ne $tabCharacterMatches

            $containsFileWithTab | Should -BeFalse -Because 'no file should have tab character(s) in them'
        }

        It 'Should not be an empty file' {
            $containsEmptyFile = [String]::IsNullOrWhiteSpace($script:fileContent)

            $containsEmptyFile | Should -BeFalse -Because 'no file should be empty'
        }

        It 'Should not contain a newline at the end' {
            if (-not [String]::IsNullOrWhiteSpace($script:fileContent) -and $script:fileContent[-1] -ne "`n")
            {
                $containsFileWithoutNewLine = $true
            }

            $containsFileWithoutNewLine | Should -BeFalse -Because 'every file should end with a new line (blank row) at the end'
        }
    }

    Context 'When markdown file ''<DescriptiveName>'' exist' -ForEach $markdownFileToTest {
        It 'Should not not have Byte Order Mark (BOM)' {
            $markdownFileHasBom = Test-FileHasByteOrderMark -FilePath $File.FullName

            $markdownFileHasBom | Should -BeFalse -Because 'no markdown file should contain Byte Order Mark (BOM). Use fixer function ''ConvertTo-ASCII''.'
        }
    }
}
