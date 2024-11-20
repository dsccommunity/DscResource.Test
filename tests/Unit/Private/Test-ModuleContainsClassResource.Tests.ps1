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
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
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


Describe 'Test-ModuleContainsClassResource' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $filePath = (Join-Path -Path $TestDrive -ChildPath 'test.psm1')
            'testfile' | Out-File -FilePath $filePath -Encoding ascii
        }
    }

    Context 'When a module contains class resources' {
        BeforeEach {
            Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                return $true
            }
        }

        It 'Should return $true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeTrue
            }

            Should -Invoke -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
        }
    }

    Context 'When a module does not contain a class resource' {
        BeforeEach {
            Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                return $false
            }
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeFalse
            }

            Should -Invoke -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
        }
    }

    Context 'When a module does not contain any resources' {
        BeforeEach {
            Mock -CommandName 'Get-Psm1FileList'
            Mock -CommandName 'Test-FileContainsClassResource'
        }

        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeFalse
            }

            Should -Invoke -CommandName 'Get-Psm1FileList' -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName 'Test-FileContainsClassResource' -Exactly -Times 0 -Scope It
        }
    }
}
