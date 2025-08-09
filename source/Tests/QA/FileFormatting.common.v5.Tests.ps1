<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/FileFormatting.common.*.Tests.ps1" -Data @{
            ProjectPath = '.'
            ModuleBase = "./output/$dscResourceModuleName/*"
            # SourcePath = './source'
            # ExcludeModuleFile = @('Modules/DscResource.Common')
            # ExcludeSourceFile = @('Examples')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param
(
    [Parameter()]
    [System.String]
    $ProjectPath,

    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter()]
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
$isPesterMinimum5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1 or higher.
if (-not $isPesterMinimum5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester v5 and v6 are skipped.' -Verbose
    return
}

<#
    This _must_ be outside any Pester blocks for correct script parsing.
    Sets Context block's default parameter value to handle Pester v6's ForEach
    change, to keep same behavior as with Pester v5. The default parameter is
    removed at the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    $textFiles = [System.Collections.Generic.List[System.Object]]::new()

    $textFiles.AddRange(@(Get-TextFilesList -Root $ModuleBase | WhereModuleFileNotExcluded -ExcludeModuleFile $ExcludeModuleFile))

    if ($SourcePath)
    {
        $textFiles.AddRange(@(Get-TextFilesList -Root $SourcePath | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile))
    }

    if ($ProjectPath)
    {
        # Expand the project folder if it is a relative path.
        $resolvedProjectPath = (Resolve-Path -Path $ProjectPath).Path
    }
    else
    {
        $resolvedProjectPath = $ModuleBase
    }

    #region Setup text file test cases.
    $textFileToTest = foreach ($file in $textFiles)
    {
        @{
            File            = $file
            # Use the project folder to extrapolate relative path.
            DescriptiveName = (Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedProjectPath)
        }
    }
    #endregion
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - File Formatting' -Tag 'Common Tests - File Formatting' {
    Context 'When code file ''<DescriptiveName>'' exist' -ForEach $textFileToTest {
        BeforeEach {
            <#
                TODO: This should be updated when issue https://github.com/dsccommunity/DscResource.Test/issues/92
                is resolved.
            #>
            if ($File.Extension -ieq '.mof')
            {
                $becauseMessage = "File $($File.FullName) should be converted to ASCII (use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-ASCII' or any other method to convert to ASCII)"
            }
            else
            {
                $becauseMessage = "File $($File.FullName) should be converted to UTF-8 (use fixer function 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8' or any other method to convert to UTF8)"
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

        It 'Should not not have Byte Order Mark (BOM)' {
            $markdownFileHasBom = Test-FileHasByteOrderMark -FilePath $File.FullName

            $markdownFileHasBom | Should -BeFalse -Because 'no text file (code or configuration) should contain Byte Order Mark (BOM) (use fixer function ''ConvertTo-ASCII'' or any other method to convert to ASCII)'
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
