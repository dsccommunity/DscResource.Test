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

Describe 'Get-PublishFileName' -Tag 'Private' {
    Context 'When the filename is in the correct format' {
        BeforeAll {
            [System.IO.FileInfo] $mockFileName = 'mockFile.ps1'

            Mock -CommandName Get-Item -MockWith {
                return $mockFileName
            }
        }

        It 'Should return the BaseName unchanged' {
            InModuleScope -Parameters @{
                mockFileName = $mockFileName
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                Get-PublishFileName -Path $mockFileName | Should -Be $mockFileName.BaseName
            }
        }
    }

    Context 'When the filename is in the incorrect format' {
        BeforeAll {
            [System.IO.FileInfo] $mockFileName = '05435-mockFile.ps1'
            [System.IO.FileInfo] $correctMockFileName = 'mockFile.ps1'

            Mock -CommandName Get-Item -MockWith {
                return $mockFileName
            }
        }

        It 'Should return the correct BaseName' {
            InModuleScope -Parameters @{
                mockFileName = $mockFileName
                correctMockFileName = $correctMockFileName
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                Get-PublishFileName -Path $mockFileName | Should -Be $correctMockFileName.BaseName
            }
        }
    }
}
