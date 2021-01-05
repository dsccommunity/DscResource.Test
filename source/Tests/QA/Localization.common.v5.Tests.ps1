<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/Localization.common.*.Tests.ps1" -Data @{
            SourcePath = './source'
            ModuleBase = "./output/$dscResourceModuleName/*"
            # ExcludeModuleFile = @('Modules/DscResource.Common')
            # ExcludeSourceFile = @('Examples')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter(Mandatory = $true)]
    [System.String]
    $SourcePath,

    [Parameter()]
    [System.String[]]
    $ExcludeModuleFile,

    [Parameter()]
    [System.String[]]
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

    $moduleFiles = @(Get-Psm1FileList -FilePath $ModuleBase | WhereModuleFileNotExcluded -ExcludeModuleFile $ExcludeModuleFile)

    $moduleFiles += Get-Psm1FileList -FilePath $SourcePath | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile

    <#
        Exclude empty PSM1. Only expect localization for Module files with some
        functions defined
    #>
    $moduleFiles = $moduleFiles | Where-Object -FilterScript {
        $_.Length -gt 0 -and (Get-FunctionDefinitionAst -FullName $_.FullName)
    }

    $fileToTest = @()

    foreach ($file in $moduleFiles)
    {
        if ($VerbosePreference -ne 'SilentlyContinue')
        {
            Write-Verbose -Message "$($file | ConvertTo-Json)"
        }

        $testProperties = @{
            File  = $file
            ParentFolderName = Split-Path -Path $file.Directory.FullName -Leaf
            LocalizationFolderPath = (Join-Path -Path $file.Directory.FullName -ChildPath 'en-US')
            LocalizationFile = (Join-Path -Path $file.Directory.FullName -ChildPath (Join-Path -Path 'en-US' -ChildPath "$($file.BaseName).strings.psd1"))
        }

        $localizedKeyToTest = @()
        $usedLocalizedKeyToTest = @()

        <#
            Build test cases for all localized strings that are in the localized
            string file and all that are used in the module file.

            Skips a file that do not exist yet (it are caught in a test)
        #>
        if (Test-Path -Path $testProperties.LocalizationFile)
        {
            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName ('{0}.strings.psd1' -f $testProperties.File.BaseName) `
                -BaseDirectory $testProperties.LocalizationFolderPath `
                -UICulture 'en-US'

            foreach ($localizedKey in $englishLocalizedStrings.Keys)
            {
                $localizedKeyToTest += @{
                    LocalizedKey = $localizedKey
                }
            }

            $parseErrors = $null

            $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($testProperties.File.FullName, [ref] $null, [ref] $parseErrors)

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
                    $usedLocalizedKeyToTest += @{
                        LocalizedKey = $localizedKey
                    }
                }
            }
        }

        $testProperties.EnUsLocalizedKeys = $localizedKeyToTest
        $testProperties.UsedLocalizedKeys = $usedLocalizedKeyToTest

        $otherLanguageToTest = @()

        # Get all localization folders except the en-US (regardless of casing).
        $localizationFolders = Get-ChildItem -Path $file.Directory.FullName -Directory -Filter '*-*' |
            Where-Object -FilterScript {
                $_.Name -ne 'en-US'
            }

        foreach ($localizationFolder in $localizationFolders)
        {
            $cultureToTest = @{
                LocalizationFolderName = Split-Path -Path $localizationFolder.FullName -Leaf
                LocalizationFolderPath = $localizationFolder.FullName
            }

            $localizedKeyToTest = @()

            <#
                Build test cases for all localized strings that are in the culture's
                localized string file.

                Skips a file that do not exist yet (it are caught in a test)
            #>
            if (Test-Path -Path $cultureToTest.LocalizationFolderPath)
            {
                Import-LocalizedData `
                    -BindingVariable 'cultureLocalizedStrings' `
                    -FileName "$($testProperties.File.BaseName).strings.psd1" `
                    -BaseDirectory $localizationFolder `
                    -UICulture $otherLanguageToTest.LocalizationFolderName

                foreach ($localizedKey in $cultureLocalizedStrings.Keys)
                {
                    $localizedKeyToTest += @{
                        CultureLocalizedKey = $localizedKey
                    }
                }
            }

            $cultureToTest.CultureLocalizedKeys = $localizedKeyToTest

            $otherLanguageToTest += $cultureToTest
        }

        $testProperties.OtherLanguages = $otherLanguageToTest

        $fileToTest += $testProperties
    }
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module 'DscResource.Test' -Force
}

Describe 'Common Tests - Validate Localization' -Tag 'Common Tests - Validate Localization' {
    Context 'When a resource or module ''<ParentFolderName>'' exist' -ForEach $fileToTest {
        It 'Should have en-US localization folder' {
            Test-Path -Path $LocalizationFolderPath | Should -BeTrue -Because "the en-US folder $LocalizationFolderPath must exist"
        }

        It 'Should have en-US localization folder with the correct casing' {
            <#
                This will return both 'en-us' and 'en-US' folders so we can
                evaluate casing.
            #>
            $localizationFolderOnDisk = Get-Item -Path $LocalizationFolderPath -ErrorAction 'SilentlyContinue'
            $localizationFolderOnDisk.Name | Should -MatchExactly 'en-US' -Because 'the en-US folder must have the correct casing'
        }

        It 'Should have en-US localization string resource file' {
            Test-Path -Path $LocalizationFile | Should -BeTrue -Because "the string resource file $LocalizationFile must exist in the localization folder en-US"
        }

        Context 'When the en-US localized resource file have localized strings' {
            <#
                This ForEach is using the key EnUsLocalizedKeys from inside the $fileToTest
                that is set on the Context-block's ForEach above.
            #>
            It 'Should use the localized string key ''<LocalizedKey>'' in the code' -ForEach $EnUsLocalizedKeys {
                $UsedLocalizedKeys.LocalizedKey | Should -Contain $LocalizedKey -Because 'the key exists in the localized string resource file so it should also exist in the resource/module script file'
            }

            <#
                This ForEach is using the key UsedLocalizedKeys from inside the $fileToTest
                that is set on the Context-block's ForEach above.
            #>
            It 'Should not be missing the localized string key ''<LocalizedKey>'' in the localization resource file' -ForEach $UsedLocalizedKeys {
                $EnUsLocalizedKeys.LocalizedKey | Should -Contain $LocalizedKey -Because 'the key is used in the resource/module script file so it should also exist in the localized string resource files'
            }
        }

        Context 'When a resource or module is localized in the language <LocalizationFolderName>' -ForEach $OtherLanguages {
            It 'Should have a localization string file in the localization folder' {
                $localizationResourceFilePath = Join-Path -Path $LocalizationFolderPath -ChildPath "$($File.BaseName).strings.psd1"

                Test-Path -Path $localizationResourceFilePath | Should -BeTrue -Because ('there must exist a string resource file ''{0}.strings.psd1'' in the localization folder ''{1}''' -f $File.BaseName, $LocalizationFolderPath)
            }

            It 'Should be an accurate localization folder with the correct casing' {
                $localizationFolderOnDisk = Get-Item -Path $LocalizationFolderPath -ErrorAction 'SilentlyContinue'
                $localizationFolderOnDisk.Name -cin ([System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures)).Name | Should -BeTrue
            }

            Context 'When the <LocalizationFolderName> localized resource file have localized strings' {
                <#
                    This ForEach is using the key CultureLocalizedKeys from inside the $fileToTest
                    that is set on the Context-block's ForEach above.
                #>
                It 'Should have the string key <CultureLocalizedKey> in the en-US localization resource file' -ForEach $CultureLocalizedKeys {
                    $EnUsLocalizedKeys.LocalizedKey | Should -Contain $CultureLocalizedKey -Because ('the key exists in the {0} localization resource file it must also also exist in the en-US localization resource file' -f $LocalizationFolderName)
                }

                <#
                    This ForEach is using the key EnUsLocalizedKeys from inside the $fileToTest
                    that is set on the Context-block's ForEach above.
                #>
                It 'Should not be missing the localization string key <LocalizedKey>'-ForEach $EnUsLocalizedKeys {
                    $CultureLocalizedKeys.CultureLocalizedKey | Should -Contain $LocalizedKey -Because ('the key exists in the en-US localization resource file so it should also exist in the {0} localization resource file (if you cannot translate the english string in the localized file, then please just add the en-US localization string key together with the en-US text string)' -f $LocalizationFolderName)
                }
            }
        }
    }
}
