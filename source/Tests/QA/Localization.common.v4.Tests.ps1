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

Describe 'Common Tests - Validate Localization' -Tag 'Common Tests - Validate Localization' {
    $moduleFiles = @(Get-Psm1FileList -FilePath $ModuleBase | WhereModuleFileNotExcluded)

    if ($SourcePath)
    {
        $moduleFiles += Get-Psm1FileList -FilePath $SourcePath | WhereSourceFileNotExcluded
    }

    <#
        Exclude empty PSM1. Only expect localization for Module files with some
        functions defined
    #>
    $moduleFiles = $moduleFiles | Where-Object -FilterScript {
        $_.Length -gt 0 -and (Get-FunctionDefinitionAst -FullName $_.FullName)
    }

    Context 'When a resource or module should have localization files' {
        BeforeAll {
            $filesToTest = @()

            foreach ($file in $moduleFiles)
            {
                Write-Verbose -Message "$($file | ConvertTo-Json)"

                $filesToTest += @{
                    LocalizationFile = (Join-Path -Path $File.Directory.FullName -ChildPath (Join-Path -Path 'en-US' -ChildPath "$($file.BaseName).strings.psd1"))
                    LocalizationFolder = (Join-Path -Path $File.Directory.FullName -ChildPath 'en-US')
                    File  = $file
                }
            }
        }

        It 'Should have en-US localization folder "<LocalizationFolder>"' -TestCases $filesToTest {
            param
            (

                [Parameter()]
                [System.String]
                $LocalizationFile,

                [Parameter()]
                [System.String]
                $LocalizationFolder,

                [Parameter()]
                [System.IO.FileInfo]
                $File
            )

            Test-Path -Path $LocalizationFolder | Should -BeTrue -Because "the en-US folder $LocalizationFolder must exist"
        }

        It 'Should have en-US localization folder "<LocalizationFolder>" with the correct casing' -TestCases $filesToTest {
            param
            (

                [Parameter()]
                [System.String]
                $LocalizationFile,

                [Parameter()]
                [System.String]
                $LocalizationFolder,

                [Parameter()]
                [System.IO.FileInfo]
                $File
            )

            <#
                This will return both 'en-us' and 'en-US' folders so we can
                evaluate casing.
            #>
            $localizationFolderOnDisk = Get-Item -Path $LocalizationFolder -ErrorAction 'SilentlyContinue'
            $localizationFolderOnDisk.Name | Should -MatchExactly 'en-US' -Because 'the en-US folder must have the correct casing'
        }

        It 'Should have en-US localization string resource file <LocalizationFile>' -TestCases $filesToTest {
            param
            (

                [Parameter()]
                [System.String]
                $LocalizationFile,

                [Parameter()]
                [System.String]
                $LocalizationFolder,

                [Parameter()]
                [System.IO.FileInfo]
                $File
            )

                Test-Path -Path $LocalizationFile | Should -BeTrue -Because "the string resource file $LocalizationFile must exist in the localization folder en-US"
        }

        foreach ($testCase in $filesToTest)
        {
            $skipTest_LocalizedKeys = $false
            $skipTest_UsedLocalizedKeys = $false

            $testCases_LocalizedKeys = @()
            $testCases_UsedLocalizedKeys = @()

            $sourceLocalizationFolderPath = $testCase.LocalizationFolder
            $localizationResourceFile = '{0}.strings.psd1' -f $testCase.File.BaseName

            # Skip files that do not exist yet (they were caught in a previous test above)
            if (-not (Test-Path -Path $testCase.LocalizationFile))
            {
                Write-Warning -Message ('Missing the localized string resource file ''{0}''' -f $testCase.LocalizationFile)

                continue
            }

            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName $localizationResourceFile `
                -BaseDirectory $sourceLocalizationFolderPath `
                -UICulture 'en-US'

            foreach ($localizedKey in $englishLocalizedStrings.Keys)
            {
                $testCases_LocalizedKeys += @{
                    LocalizedKey = $localizedKey
                }
            }

            $modulePath = $testCase.File.FullName

            $parseErrors = $null
            $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref] $null, [ref] $parseErrors)

            if ($parseErrors)
            {
                throw $parseErrors
            }

            $astFilter = {
                $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] `
                -and $args[0].Parent -is [System.Management.Automation.Language.MemberExpressionAst] `
                -and $args[0].Parent.Expression -is [System.Management.Automation.Language.VariableExpressionAst] `
                -and $args[0].Parent.Expression.VariablePath.UserPath -eq 'script:localizedData'
            }

            $localizationStringConstantsAst = $definitionAst.FindAll($astFilter, $true)

            if ($localizationStringConstantsAst)
            {
                $usedLocalizationKeys = $localizationStringConstantsAst.Value | Sort-Object -Unique

                foreach ($localizedKey in $usedLocalizationKeys)
                {
                    $testCases_UsedLocalizedKeys += @{
                        LocalizedKey = $localizedKey
                    }
                }
            }

            Context ('When validating module file {0}' -f $testCase.File.FullName) {
                # If there are no test cases built, skip this test.
                $skipTest_LocalizedKeys = -not $testCases_LocalizedKeys

                It 'Should use the localized string key <LocalizedKey> from the localization resource file' -TestCases $testCases_LocalizedKeys -Skip:$skipTest_LocalizedKeys {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $LocalizedKey
                    )

                    $usedLocalizationKeys | Should -Contain $LocalizedKey -Because 'the key exists in the localized string resource file so it should also exist in the code'
                }

                # If there are no test cases built, skip this test.
                $skipTest_UsedLocalizedKeys = -not $testCases_UsedLocalizedKeys

                It 'Should not be missing the localized string key <LocalizedKey> from the localization resource file' -TestCases $testCases_UsedLocalizedKeys -Skip:$skipTest_UsedLocalizedKeys {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $LocalizedKey
                    )

                    $englishLocalizedStrings.Keys | Should -Contain $LocalizedKey -Because 'the key is used in the resource/module script file so it should also exist in the localized string resource files'
                }
            }
        }
    }

    Context 'When a resource or module is localized to other languages' {
        BeforeAll {
            $otherLanguagesToTest = @()

            foreach ($file in $moduleFiles)
            {
                <#
                    Get all localization folders except the en-US.
                    We want all regardless of casing.
                #>
                $localizationFolders = Get-ChildItem -Path $file.Directory.FullName -Directory -Filter '*-*' |
                    Where-Object -FilterScript {
                        $_.Name -ne 'en-US'
                    }

                foreach ($localizationFolder in $localizationFolders)
                {
                    $otherLanguagesToTest += @{
                        Folder             = $file.Directory.Name
                        Path               = $file.Directory.FullName
                        LocalizationFolder = $localizationFolder.FullName
                        File               = $file
                    }
                }
            }
        }

        # Only run these tests if there are test cases to be tested.
        $skipTests = -not $otherLanguagesToTest

        It 'Should have a localization string file in the localization folder <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
            param
            (
                [Parameter()]
                [System.String]
                $Folder,

                [Parameter()]
                [System.String]
                $Path,

                [Parameter()]
                [System.String]
                $LocalizationFolder,

                [Parameter()]
                [System.IO.FileInfo]
                $File
            )

            $localizationResourceFilePath = Join-Path -Path $LocalizationFolder -ChildPath "$($File.BaseName).strings.psd1"

            Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because ('there must exist a string resource file in the localization folder {0}' -f $LocalizationFolder)
        }

        It 'Should have a localization folder with the correct casing <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
            param
            (
                [Parameter()]
                [System.String]
                $Folder,

                [Parameter()]
                [System.String]
                $Path,

                [Parameter()]
                [System.String]
                $LocalizationFolder,

                [Parameter()]
                [System.IO.FileInfo]
                $File
            )

            $localizationFolderOnDisk = Get-Item -Path $LocalizationFolder -ErrorAction 'SilentlyContinue'
            $localizationFolderOnDisk.Name -cin ([System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures)).Name | Should -BeTrue
        }

        foreach ($testCase in $otherLanguagesToTest)
        {
            $testCases_CompareAgainstEnglishLocalizedKeys = @()
            $testCases_MissingEnglishLocalizedKeys = @()
            $UICultureUnderTest = Split-Path -leaf -Path $testCase.LocalizationFolder
            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName "$($testCase.File.BaseName).strings.psd1" `
                -BaseDirectory $testCase.Path `
                -UICulture 'en-US'

            $localizationFolderPath = $testCase.LocalizationFolder

            Import-LocalizedData `
                -BindingVariable 'localizedStrings' `
                -FileName "$($testCase.File.BaseName).strings.psd1" `
                -BaseDirectory $localizationFolderPath `
                -UICulture $UICultureUnderTest

            foreach ($localizedKey in $englishLocalizedStrings.Keys)
            {
                $testCases_CompareAgainstEnglishLocalizedKeys += @{
                    LocalizationFolder = $testCase.LocalizationFolder
                    Folder             = $testCase.Folder
                    LocalizedKey       = $localizedKey
                }
            }

            foreach ($localizedKey in $localizedStrings.Keys)
            {
                $testCases_MissingEnglishLocalizedKeys += @{
                    LocalizationFolder = $testCase.LocalizationFolder
                    Folder             = $testCase.Folder
                    LocalizedKey       = $localizedKey
                }
            }

            Context ('When validating module file {0}' -f $testCase.Folder) {
                It "Should have the string key <LocalizedKey> in the localization resource file '<LocalizationFolder>\<Folder>.strings.psd1' as per the en-US reference" -TestCases $testCases_CompareAgainstEnglishLocalizedKeys {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $LocalizedKey,

                        [Parameter()]
                        [System.String]
                        $Folder,

                        [Parameter()]
                        [System.String]
                        $LocalizationFolder
                    )

                    $localizedStrings.Keys | Should -Contain $LocalizedKey -Because 'the key exists in the en-US localization resource file so the key should also exist in this language file'
                }  -ErrorVariable itBlockError

                <#
                    If the It-block did not pass the test, output the a text
                    explaining how to resolve the issue.
                #>
                if ($itBlockError.Count -ne 0)
                {
                    $message = @"
If you cannot translate the english string in the localized file,
then please just add the en-US localization string key together
with the en-US text string.
"@

                    Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
                    Write-Host -ForegroundColor White -Object ''
                }

                It "Should not be missing the localization string key <LocalizedKey> from the english resource file for the resource/module <Folder>" -TestCases $testCases_MissingEnglishLocalizedKeys {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $LocalizedKey,

                        [Parameter()]
                        [System.String]
                        $Folder,

                        [Parameter()]
                        [System.String]
                        $LocalizationFolder
                    )

                    $englishLocalizedStrings.Keys | Should -Contain $LocalizedKey -Because ('the key exists in the resource file for the location folder {0} so it should also exist in the en-US string resource file' -f $LocalizationFolder)
                }
            }
        }
    }
}
