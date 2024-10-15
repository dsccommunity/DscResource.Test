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

Describe 'Join-PSModulePath' -Tag 'Private' {
    Context 'When the ''NewPath'' does not exist in the ''Path''' {
        It 'Should add the path' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $mockPath = 'string1;string2'
                $mockNewPath = 'string3;string4'
                $expectedResult = $mockPath + ';' + $mockNewPath

                Join-PSModulePath -Path $mockPath -NewPath $mockNewPath | Should -Be $expectedResult
            }
        }
    }

    Context 'When the ''NewPath'' does exist in the ''Path''' {
        It 'Should add the path' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $mockPath = 'string1;string2'
                $mockNewPath = 'string3;string2'
                $expectedResult = $mockPath + ';string3'

                Join-PSModulePath -Path $mockPath -NewPath $mockNewPath | Should -Be $expectedResult
            }
        }
    }
}
