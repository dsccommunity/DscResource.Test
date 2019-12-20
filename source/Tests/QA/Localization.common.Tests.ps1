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

Describe 'Common Tests - Validate Localization' -Tag 'Common Tests - Validate Localization' {
    $allFolders = Get-ChildItem -Path (Join-Path -Path $ModuleBase -ChildPath 'DscResources') -Directory
    $allFolders += Get-ChildItem -Path (Join-Path -Path $ModuleBase -ChildPath 'Modules') -Directory
    $allFolders = $allFolders | Sort-Object -Property Name

    Context 'When a resource or module should have localization files' {
        BeforeAll {
            $foldersToTest = @()

            foreach ($folder in $allFolders)
            {
                $foldersToTest += @{
                    Folder = $folder.Name
                    Path   = $folder.FullName
                }
            }
        }

        It 'Should have en-US localization folder for the resource/module <Folder>' -TestCases $foldersToTest {
            param
            (
                [Parameter()]
                [System.String]
                $Folder,

                [Parameter()]
                [System.String]
                $Path
            )

            $localizationFolderPath = Join-Path -Path $Path -ChildPath 'en-US'

            Test-Path -Path $localizationFolderPath | Should -BeTrue -Because 'the en-US folder must exist'
        }

        It 'Should have en-US localization folder with the correct casing for the resource/module <Folder>' -TestCases $foldersToTest {
            param
            (
                [Parameter()]
                [System.String]
                $Folder,

                [Parameter()]
                [System.String]
                $Path
            )

            <#
                This will return both 'en-us' and 'en-US' folders so we can
                evaluate casing.
            #>
            $localizationFolderOnDisk = Get-ChildItem -Path $Path -Directory -Filter 'en-US'
            $localizationFolderOnDisk.Name | Should -MatchExactly 'en-US' -Because 'the en-US folder must have the correct casing'
        }

        It 'Should have en-US localization string resource file for the resource/module <Folder>' -TestCases $foldersToTest {
            param
            (
                [Parameter()]
                [System.String]
                $Folder,

                [Parameter()]
                [System.String]
                $Path
            )

            $localizationResourceFilePath = Join-Path -Path (Join-Path -Path $Path -ChildPath 'en-US') -ChildPath "$Folder.strings.psd1"

            Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because 'there must exist a string resource file in the localization folder en-US'
        }

        foreach ($testCase in $foldersToTest)
        {
            $skipTest_LocalizedKeys = $false
            $skipTest_UsedLocalizedKeys = $false

            $testCases_LocalizedKeys = @()
            $testCases_UsedLocalizedKeys = @()

            $sourceLocalizationFolderPath = Join-Path -Path $testCase.Path -ChildPath 'en-US'
            $localizationResourceFile = '{0}.strings.psd1' -f $testCase.Folder

            # Skip files that do not exist yet (they were caught in a previous test above)
            if (-not (Test-Path -Path (Join-Path -Path $sourceLocalizationFolderPath -ChildPath $localizationResourceFile)))
            {
                Write-Warning -Message ('Missing the localized string resource file ''{0}''' -f $testCase.Path)

                continue
            }

            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName $localizationResourceFile `
                -BaseDirectory $sourceLocalizationFolderPath

            foreach ($localizedKey in $englishLocalizedStrings.Keys)
            {
                $testCases_LocalizedKeys += @{
                    LocalizedKey = $localizedKey
                }
            }

            $modulePath = Join-Path -Path $testCase.Path -ChildPath "$($testCase.Folder).psm1"

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

            Context ('When validating resource/module {0}' -f $testCase.Folder) {
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

            foreach ($folder in $allFolders)
            {
                <#
                    Get all localization folders except the en-US.
                    We want all regardless of casing.
                #>
                $localizationFolders = Get-ChildItem -Path $folder.FullName -Directory -Filter '*-*' |
                    Where-Object -FilterScript {
                        $_.Name -ne 'en-US'
                    }

                foreach ($localizationFolder in $localizationFolders)
                {
                    $otherLanguagesToTest += @{
                        Folder             = $folder.Name
                        Path               = $folder.FullName
                        LocalizationFolder = $localizationFolder.Name
                    }
                }
            }
        }

        # Only run these tests if there are test cases to be tested.
        $skipTests = -not $otherLanguagesToTest

        It 'Should have a localization string resource file for the resource/module <Folder> and localization folder <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
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
                $LocalizationFolder
            )

            $localizationResourceFilePath = Join-Path -Path (Join-Path -Path $Path -ChildPath $LocalizationFolder) -ChildPath "$Folder.strings.psd1"

            Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because ('there must exist a string resource file in the localization folder {0}' -f $LocalizationFolder)
        }

        It 'Should have a localization folder with the correct casing for the resource/module <Folder> and localization folder <LocalizationFolder>' -TestCases $otherLanguagesToTest -Skip:$skipTests {
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
                $LocalizationFolder
            )

            $localizationFolderOnDisk = Get-ChildItem -Path $Path -Directory -Filter $LocalizationFolder
            $localizationFolderOnDisk.Name | Should -MatchExactly '[a-z]{2}-[A-Z]{2}' -Because 'the localization folder must have the correct casing'
        }

        foreach ($testCase in $otherLanguagesToTest)
        {
            $testCases_CompareAgainstEnglishLocalizedKeys = @()
            $testCases_MissingEnglishLocalizedKeys = @()

            $sourceLocalizationFolderPath = Join-Path -Path $testCase.Path -ChildPath 'en-US'

            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName "$($testCase.Folder).strings.psd1" `
                -BaseDirectory $sourceLocalizationFolderPath

            $localizationFolderPath = Join-Path -Path $testCase.Path -ChildPath $testCase.LocalizationFolder

            Import-LocalizedData `
                -BindingVariable 'localizedStrings' `
                -FileName "$($testCase.Folder).strings.psd1" `
                -BaseDirectory $localizationFolderPath

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

            Context ('When validating resource/module {0}' -f $testCase.Folder) {
                It "Should have the english localization string key <LocalizedKey> in the localization resource file '<LocalizationFolder>\<Folder>.strings.psd1' for the resource/module <Folder>" -TestCases $testCases_CompareAgainstEnglishLocalizedKeys {
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
