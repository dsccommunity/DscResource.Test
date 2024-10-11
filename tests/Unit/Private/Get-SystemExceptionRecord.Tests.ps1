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

Describe 'Get-SystemExceptionRecord' -Tag 'Private' {
    Context 'When calling with the parameter Message' {
        It 'Should have the correct values in the error record' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-SystemExceptionRecord -Message 'mocked error message.' -Exception 'System.Exception'

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message | Should -Be 'System.Exception: mocked error message.'
            }
        }
    }

    Context 'When calling with the parameters Message and ErrorRecord' {
        It 'Should have the correct values in the error record' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = $null

                try
                {
                    # Force divide by zero exception.
                    1 / 0
                }
                catch
                {
                    $result = Get-SystemExceptionRecord -Message 'mocked error message.' -Exception 'System.InvalidOperationException' -ErrorRecord $_
                }

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message -match 'System.InvalidOperationException: mocked error message.' | Should -BeTrue
                $result.Exception.Message -match 'System.Management.Automation.RuntimeException: Attempted to divide by zero.' | Should -BeTrue
                $result.Exception.Message -match 'System.DivideByZeroException: Attempted to divide by zero.' | Should -BeTrue
            }
        }
    }
}
