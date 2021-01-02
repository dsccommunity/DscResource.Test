[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Scope='Function', Target='*')]
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

Describe 'Common Tests - Validate Example Files To Be Published' -Tag 'Common Tests - Validate Example Files To Be Published' {
    $examplesPath = Join-Path -Path $SourcePath -ChildPath 'Examples'

    if (Test-Path -Path $examplesPath)
    {
        Context 'When there are examples that should be published' {
            $exampleScriptFiles = Get-ChildItem -Path (Join-Path -Path $examplesPath -ChildPath '*Config.ps1') -Recurse

            It 'Should not contain any duplicate GUIDs in the script file metadata' {
                $exampleScriptMetadata = $exampleScriptFiles | ForEach-Object -Process {
                    <#
                        The cmdlet Test-ScriptFileInfo ignores the parameter ErrorAction and $ErrorActionPreference.
                        Instead a try-catch need to be used to ignore files that does not have the correct metadata.
                    #>
                    try
                    {
                        Test-ScriptFileInfo -Path $_.FullName
                    }
                    catch
                    {
                        # Intentionally left blank. Files with missing metadata will be caught in the next test.
                    }
                }

                $duplicateGuids = @($exampleScriptMetadata | `
                    Group-Object -Property Guid | `
                    Where-Object -FilterScript {
                        $_.Count -gt 1
                    }
                )

                if ($duplicateGuids.Count -gt 0)
                {
                    foreach ($duplicateGuid in $duplicateGuids)
                    {
                        $duplicateGuidSummary = [PSCustomObject]@{
                            Name  = $duplicateGuid.Name
                            Files = $duplicateGuid.Group.Name -join ', '
                        }
                    }

                    $report = $duplicateGuidSummary | Format-Table -AutoSize -Wrap | Out-String -Width 110
                    $duplicateGuids.Count | Should -Be 0 -Because "duplicate guids:`r`n`r`n $report`r`n `r`n ,"
                }
            }

            foreach ($exampleToValidate in $exampleScriptFiles)
            {
                $exampleDescriptiveName = Join-Path -Path (Split-Path -Path $exampleToValidate.Directory -Leaf) `
                    -ChildPath (Split-Path -Path $exampleToValidate -Leaf)

                Context "When publishing example '$exampleDescriptiveName'" {
                    It 'Should pass testing of script file metadata' {
                        { Test-ScriptFileInfo -Path $exampleToValidate.FullName } | Should -Not -Throw
                    }

                    It 'Should have the correct naming convention, and the same file name as the configuration name' {
                        Test-ConfigurationName -Path $exampleToValidate.FullName | Should -BeTrue
                    }
                }
            }
        }
    }
}
