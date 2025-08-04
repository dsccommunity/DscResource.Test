<#
    .NOTES
        To run manually:

        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/PublishExampleFiles.common.*.Tests.ps1" -Data @{
            SourcePath = './source'
            # ExcludeSourceFile = @('MyExample.ps1')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param
(
    [Parameter()]
    [System.String]
    $SourcePath,

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

if (-not $SourcePath)
{
    Write-Verbose -Message 'The Publish Example files tests only apply to Source repository testing.'
    return
}

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    $examplesPath = Join-Path -Path $SourcePath -ChildPath 'Examples'

    # If there are no Examples folder, exit.
    if (-not (Test-Path -Path $examplesPath))
    {
        return
    }

    $exampleScriptFilesToPublish = @(Get-ChildItem -Path $examplesPath -Filter '*Config.ps1' -Recurse | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile)

    $exampleToTest = foreach ($exampleFile in $exampleScriptFilesToPublish)
    {
        @{
            ExampleFile            = $exampleFile
            ExampleDescriptiveName = Join-Path -Path (Split-Path $exampleFile.Directory -Leaf) -ChildPath (Split-Path $exampleFile -Leaf)
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


Describe 'Common Tests - Validate Example Files To Be Published' -Tag 'Common Tests - Validate Example Files To Be Published' {
    BeforeAll {
        $exampleScriptFilesToPublish = @(Get-ChildItem -Path $examplesPath -Filter '*Config.ps1' -Recurse | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile)

        # Get the GUID's for all the example files.
        $exampleScriptMetadata = foreach ($file in $exampleScriptFilesToPublish)
        {
            <#
                The cmdlet Test-ScriptFileInfo ignores the parameter ErrorAction and $ErrorActionPreference.
                Instead a try-catch need to be used to ignore files that does not have the correct metadata.
            #>
            try
            {
                $info = Test-ScriptFileInfo -Path $file.FullName

                @{
                    Name = $info.Name
                    Guid = $info.Guid
                }
            }
            catch
            {
                # Intentionally left blank. Files with missing metadata will be caught in the tests.
            }
        }
    }

    Context 'When example ''<ExampleDescriptiveName>'' should be published' -ForEach $exampleToTest {
        It 'Should pass testing of script file metadata' {
            { Test-ScriptFileInfo -Path $ExampleFile.FullName } | Should -Not -Throw -Because 'each example that should be published must have a script file info'
        }

        It 'Should have the correct naming convention and have the same file name as the configuration name' {
            Test-ConfigurationName -Path $ExampleFile.FullName | Should -BeTrue -Because 'the configuration name and the file name must be equal except for the ordinal number, and the name must start with a letter, it must end with a letter or a number, and only contain letters, numbers, and underscores (e.g ''ResourceName_ExampleName_Config.ps1'')'
        }

        It 'Should not have the script file information metadata GUID duplicated in another example file' {
            try
            {
                $metadataGuid = Test-ScriptFileInfo -Path $ExampleFile.FullName
            }
            catch
            {
                <#
                    Ignore if the metatdata could not be read, files with missing
                    metadata was caught in the previous test.
                #>
                Set-ItResult -Inconclusive -Because 'the example script file information metadata could not be read'
            }

            $exampleFilesWithSameGuid = @($exampleScriptMetadata | Where-Object -FilterScript { $_.Guid -eq $metadataGuid.Guid })

            $report = $exampleFilesWithSameGuid | Format-Table -AutoSize -Wrap | Out-String -Width 110

            $exampleFilesWithSameGuid.Count | Should -BeExactly 1 -Because "two example files may not have the same GUID: `r`n`r`n $report`r`n `r`n"
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
