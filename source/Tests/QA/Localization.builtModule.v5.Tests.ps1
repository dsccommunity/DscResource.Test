<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/Localization.builtModule.*.Tests.ps1" -Data @{
            ModuleBase = "./output/$dscResourceModuleName/*"
            ProjectPath = '.'
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter()]
    [System.String]
    $ProjectPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPesterMinimum5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1 or higher.
if (-not $isPesterMinimum5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester v5 and v6 are skipped.' -Verbose
    return
}

<#
    This _must_ be outside any Pester blocks for correct script parsing. Sets It
    and Context block's default parameter value to handle Pester v6's ForEach change,
    to keep same behavior as with Pester v5. The default parameter is removed at
    the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true
$PSDefaultParameterValues['It:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    # trim * from modulebase for -Depth to work
    $localModuleBase = $ModuleBase.Replace('*', '')

    $moduleFiles = @(Get-ChildItem -Path $localModuleBase -Filter '*.psm1' -Depth 1)

    if ($ProjectPath)
    {
        # Expand the project folder if it is a relative path.
        $resolvedProjectPath = (Resolve-Path -Path $ProjectPath).Path
    }
    else
    {
        $resolvedProjectPath = $ModuleBase
    }

    <#
        Exclude empty PSM1. Only expect localization for Module files with some
        functions defined
    #>
    $moduleFiles = $moduleFiles | Where-Object -FilterScript {
        <#
            Ignore parse errors in the script files. Parse error will be caught
            in the tests in ModuleScriptFiles.common.
        #>
        $currentPath = $_.FullName

        try
        {
            Get-FunctionDefinitionAst -FullName $currentPath

            $valid = $true
        }
        catch
        {
            # Outputting the error just in case there is another error than parse error.
            Write-Warning -Message ('File ''{0}'' is skipped because it could not be parsed. Error message: {1}' -f $currentPath, $_.Exception.Message)

            $valid = $false
        }

        $_.Length -gt 0 -and $valid
    }

    $scriptLocalizationToTest = @()
    $thisLocalizationToTest = @()

    foreach ($file in $moduleFiles)
    {
        if ($VerbosePreference -ne 'SilentlyContinue')
        {
            Write-Verbose -Message "$($file | ConvertTo-Json)"
        }

        # Use the project folder to extrapolate relative path.
        $descriptiveName = Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedProjectPath

        $scriptTestProperties = @{
            File                   = $file
            DescriptiveName        = $descriptiveName
            LocalizationFolderPath = (Join-Path -Path $file.Directory.FullName -ChildPath 'en-US')
            LocalizationFile       = (Join-Path -Path $file.Directory.FullName -ChildPath (Join-Path -Path 'en-US' -ChildPath "$($file.BaseName).strings.psd1"))
        }

        $localizedKeyToTest = @()
        $usedLocalizedKeyToTest = @()

        <#
        Build test cases for all localized strings that are in the localized
        string file and all that are used in the module file.

        Skips a file that do not exist yet (it are caught in a test)
        #>
        if (Test-Path -Path $scriptTestProperties.LocalizationFile)
        {
            Import-LocalizedData `
                -BindingVariable 'englishLocalizedStrings' `
                -FileName ('{0}.strings.psd1' -f $scriptTestProperties.File.BaseName) `
                -BaseDirectory $scriptTestProperties.LocalizationFolderPath `
                -UICulture 'en-US'

            foreach ($localizedKey in $englishLocalizedStrings.Keys)
            {
                $localizedKeyToTest += @{
                    LocalizedKey = $localizedKey
                }
            }

            $definitionAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptTestProperties.File.FullName, [ref] $null, [ref] $null)

            # Look for script:localizedData
            $astFilter = {
                $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $args[0].Parent -is [System.Management.Automation.Language.MemberExpressionAst] -and
                $args[0].Parent.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $args[0].Parent.Expression.VariablePath.UserPath -eq 'script:localizedData'
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

        $scriptTestProperties.EnUsLocalizedKeys = $localizedKeyToTest
        $scriptTestProperties.UsedLocalizedKeys = $usedLocalizedKeyToTest

        $otherLanguageToTest = @()

        # Get all localization folders except the en-US (regardless of casing).
        $localizationFolders = Get-ChildItem -Path $scriptTestProperties.File.Directory.FullName -Directory -Filter '*-*' |
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
                    -FileName "$($scriptTestProperties.File.BaseName).strings.psd1" `
                    -BaseDirectory $cultureToTest.LocalizationFolderPath `
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

        $scriptTestProperties.OtherLanguages = $otherLanguageToTest

        $scriptLocalizationToTest += $scriptTestProperties

        # Now check the class localization for this file
        $classDefinitionAst = Get-ClassDefinitionAst -FullName $file.FullName

        foreach ($class in $classDefinitionAst)
        {
            if ($class.Attributes.TypeName.Name -ieq 'DscResource')
            {
                $classTestProperties = @{
                    ClassName              = $class.Name
                    LocalizationFolderPath = $scriptTestProperties.LocalizationFolderPath
                    LocalizationFile       = (Join-Path -Path $file.Directory.FullName -ChildPath (Join-Path -Path 'en-US' -ChildPath "$($class.Name).strings.psd1"))
                }
            }
            else
            {
                # if this is not a DscResource then skip to next item
                continue
            }

            $localizedKeyToTest = @()
            $usedLocalizedKeyToTest = @()

            <#
            Build test cases for all localized strings that are in the localized
            string file and all that are used in the module file.

            Skips a file that do not exist yet (it are caught in a test)
            #>
            if (Test-Path -Path $classTestProperties.LocalizationFile)
            {
                Import-LocalizedData `
                    -BindingVariable 'englishLocalizedStrings' `
                    -FileName ('{0}.strings.psd1' -f $class.Name) `
                    -BaseDirectory $classTestProperties.LocalizationFolderPath `
                    -UICulture 'en-US'

                foreach ($localizedKey in $englishLocalizedStrings.Keys)
                {
                    $localizedKeyToTest += @{
                        LocalizedKey = $localizedKey
                    }
                }

                # Look for $this.localizedData
                $astFilter = {
                    $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                    $args[0].Parent -is [System.Management.Automation.Language.MemberExpressionAst] -and
                    $args[0].Parent.Expression.Member.Value -eq 'localizedData'
                }

                $localizationStringConstantsAst = $class.FindAll($astFilter, $true)

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

            $classTestProperties.EnUsLocalizedKeys = $localizedKeyToTest
            $classTestProperties.UsedLocalizedKeys = $usedLocalizedKeyToTest

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
                    ClassName              = $class.Name
                }

                $localizedKeyToTest = @()

                <#
                Build test cases for all localized strings that are in the culture's
                localized string file.

                Skips a file that do not exist yet (it are caught in a test)
                #>
                $localizationFile = (Join-Path -Path $cultureToTest.LocalizationFolderPath -ChildPath "$($class.Name).strings.psd1")
                $cultureToTest.LocalizationFile = $localizationFile

                if (Test-Path -Path $localizationFile)
                {
                    Import-LocalizedData `
                        -BindingVariable 'cultureLocalizedStrings' `
                        -FileName "$($class.Name).strings.psd1" `
                        -BaseDirectory $cultureToTest.LocalizationFolderPath `
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

            $classTestProperties.OtherLanguages = $otherLanguageToTest

            $thisLocalizationToTest += $classTestProperties
        }
    }
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'BuiltModule Tests - Validate Localization' -Tag 'BuiltModule Tests - Validate Localization' {
    Context 'When the module ''<DescriptiveName>'' exists' -ForEach $scriptLocalizationToTest {
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

    Context 'When the class ''<ClassName>'' exists' -ForEach $thisLocalizationToTest {
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
                Test-Path -Path $LocalizationFile | Should -BeTrue -Because ('there must exist a string resource file ''{0}.strings.psd1'' in the localization folder ''{1}''' -f $ClassName, $LocalizationFolderPath)
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

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
$PSDefaultParameterValues.Remove('It:AllowNullOrEmptyForEach')
