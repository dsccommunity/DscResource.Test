$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

if ($PSVersionTable.PSVersion.Major -gt 5)
{
    return
}

Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Restore-TestEnvironment' {
        BeforeAll {
            Mock -CommandName 'Clear-DscLcmConfiguration'
            Mock -CommandName 'Set-PSModulePath'
            Mock -CommandName 'Set-ExecutionPolicy'

            $testCases = @(
                @{
                    TestDescription = 'when restoring from a unit test'
                    TestEnvironment = @{
                        DSCModuleName      = 'TestModule'
                        DSCResourceName    = 'TestResource'
                        TestType           = 'Unit'
                        ImportedModulePath = $moduleToImportFilePath
                        OldPSModulePath    = $env:PSModulePath
                        OldExecutionPolicy = Get-ExecutionPolicy
                    }
                },

                @{
                    TestDescription = 'when restoring from an integration test'
                    TestEnvironment = @{
                        DSCModuleName      = 'TestModule'
                        DSCResourceName    = 'TestResource'
                        TestType           = 'Integration'
                        ImportedModulePath = $moduleToImportFilePath
                        OldPSModulePath    = $env:PSModulePath
                        OldExecutionPolicy = Get-ExecutionPolicy
                    }
                }
            )
        }

        Context 'When restoring the test environment' {
            It 'Should restore without throwing <TestDescription>' -TestCases $testCases {
                param
                (
                    # String containing a description to add to the It-block name
                    [Parameter()]
                    [System.String]
                    $TestDescription,

                    # Hash table containing the test environment
                    [Parameter()]
                    [System.Collections.HashTable]
                    $TestEnvironment
                )

                { Restore-TestEnvironment -TestEnvironment $TestEnvironment } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Set-PSModulePath' -Exactly -Times 0
            }
        }

        # Regression test for issue #70.
        Context 'When restoring the test environment from an integration test that changed the PSModulePath' {
            It 'Should restore without throwing and call the correct mocks' {
                $testEnvironmentParameter = @{
                    DSCModuleName      = 'TestModule'
                    DSCResourceName    = 'TestResource'
                    TestType           = 'Integration'
                    ImportedModulePath = $moduleToImportFilePath
                    OldPSModulePath    = 'Wrong paths'
                    OldExecutionPolicy = Get-ExecutionPolicy
                }

                { Restore-TestEnvironment -TestEnvironment $testEnvironmentParameter } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Clear-DscLcmConfiguration' -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $Path -eq $testEnvironmentParameter.OldPSModulePath `
                        -and $PSBoundParameters.ContainsKey('Machine') -eq $false
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When restoring the test environment from an integration test that changed the machine PSModulePath' {
            BeforeAll {
                if ($script:machineOldPSModulePath)
                {
                    throw 'The script variable $script:machineOldPSModulePath was already set, cannot run unit test. This should not happen unless the test is run in the context of an integration test.'
                }

                $script:machineOldPSModulePath = 'SavedPath'
            }

            AfterAll {
                $script:machineOldPSModulePath = $null
            }

            It 'Should restore without throwing and call the correct mocks' {
                $testEnvironmentParameter = @{
                    DSCModuleName      = 'TestModule'
                    DSCResourceName    = 'TestResource'
                    TestType           = 'Integration'
                    ImportedModulePath = $moduleToImportFilePath
                    OldPSModulePath    = 'Wrong paths'
                    OldExecutionPolicy = Get-ExecutionPolicy
                }

                { Restore-TestEnvironment -TestEnvironment $testEnvironmentParameter -KeepNewMachinePSModulePath } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Clear-DscLcmConfiguration' -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $Path -eq $testEnvironmentParameter.OldPSModulePath `
                        -and $PSBoundParameters.ContainsKey('Machine') -eq $false
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $Path -match 'SavedPath' `
                        -and $PSBoundParameters.ContainsKey('Machine') -eq $true
                } -Exactly -Times 1 -Scope It
            }
        }

        Context 'When restoring the test environment from an integration test that has the wrong execution policy' {
            BeforeAll {
                <#
                    Find out which execution policy should be used when mocking
                    the test parameters.
                #>
                if ((Get-ExecutionPolicy) -ne [Microsoft.PowerShell.ExecutionPolicy]::AllSigned )
                {
                    $mockExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::AllSigned
                }
                else
                {
                    $mockExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Unrestricted
                }
            }

            It 'Should restore without throwing' {
                $testEnvironmentParameter = @{
                    DSCModuleName      = 'TestModule'
                    DSCResourceName    = 'TestResource'
                    TestType           = 'Integration'
                    ImportedModulePath = $moduleToImportFilePath
                    OldPSModulePath    = $env:PSModulePath
                    OldExecutionPolicy = $mockExecutionPolicy
                }

                { Restore-TestEnvironment -TestEnvironment $testEnvironmentParameter } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It
            }
        }
    }
}
