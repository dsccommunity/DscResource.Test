[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:moduleName = 'DscResource.Test'

    # Make sure there are not other modules imported that will conflict with mocks.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Restore-TestEnvironment' -Tag 'Public' -Skip:($PSVersionTable.PSVersion.Major -gt 5) {
    BeforeDiscovery {
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

    BeforeAll {
        Mock -CommandName 'Clear-DscLcmConfiguration'
        Mock -CommandName 'Set-PSModulePath'
        Mock -CommandName 'Set-ExecutionPolicy'
    }

    Context 'When restoring the test environment' {
        It 'Should restore without throwing <TestDescription>' -TestCases $testCases {
            { Restore-TestEnvironment -TestEnvironment $TestEnvironment } | Should -Not -Throw

            Should -Invoke -CommandName 'Set-PSModulePath' -Exactly -Times 0
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

            Should -Invoke -CommandName 'Clear-DscLcmConfiguration' -Exactly -Times 1 -Scope It

            Should -Invoke -CommandName 'Set-PSModulePath' -ParameterFilter {
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

            Should -Invoke -CommandName 'Clear-DscLcmConfiguration' -Exactly -Times 1 -Scope It

            Should -Invoke -CommandName 'Set-PSModulePath' -ParameterFilter {
                $Path -eq $testEnvironmentParameter.OldPSModulePath `
                    -and $PSBoundParameters.ContainsKey('Machine') -eq $false
            } -Exactly -Times 1 -Scope It

            Should -Invoke -CommandName 'Set-PSModulePath' -ParameterFilter {
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

            Should -Invoke -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It
        }
    }
}
