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

Describe 'Get-ClassResourceNameFromFile' -Tag 'Private' {
    BeforeAll {
            $mockResourceName1 = 'TestResourceName1'
            $mockResourceName2 = 'TestResourceName2'

            $mockScriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
    }

    Context 'When querying for the name of a class-based resource' {
        It 'Should return the correct name of the resource' {
            InModuleScope -Parameters @{
                mockScriptPath = $mockScriptPath
                mockResourceName1 = $mockResourceName1
                mockResourceName2 = $mockResourceName2
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                [DscResource()]
                class $mockResourceName1
                {
                    [DscProperty(Key)]
                    [string] `$Name

                    [void] Set() {}
                    [bool] Test() { return `$true }
                    [$mockResourceName1] Get() { return `$this }
                }

                [DscResource()]
                class $mockResourceName2
                {
                    [DscProperty(Key)]
                    [string] `$Name

                    [void] Set() {}
                    [bool] Test() { return `$true }
                    [$mockResourceName2] Get() { return `$this }
                }
                " | Out-File -FilePath $mockScriptPath -Encoding ascii -Force

                $result = Get-ClassResourceNameFromFile -FilePath $mockScriptPath
                $result.Count | Should -Be 2
                $result[0] | Should -Be $mockResourceName1
                $result[1] | Should -Be $mockResourceName2
            }
        }
    }
}
