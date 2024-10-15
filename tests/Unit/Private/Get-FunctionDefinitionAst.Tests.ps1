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

Describe 'Get-FunctionDefinitionAst' -Tag 'Private' {
    BeforeAll {
        $mockScriptPath = Join-Path -Path $TestDrive -ChildPath 'TestFunctions.ps1'
    }

    Context 'When a script file has function definitions' {
        BeforeAll {
            $definition = '
                function Get-Something
                {
                    return "test1"
                }

                function Get-SomethingElse
                {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $Param1
                    )

                    return $Param1
                }
            '

            $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
        }

        It 'Should return the correct number of function definitions' {
            InModuleScope -Parameters @{
                mockScriptPath = $mockScriptPath
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-FunctionDefinitionAst -FullName $mockScriptPath
                $result | Should -HaveCount 2
            }
        }
    }

    Context 'When a script file has no function definitions' {
        BeforeAll {
            $definition = '
                $script:variable = 1
                return $script:variable
            '

            $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
        }

        It 'Should return $null' {
            InModuleScope -Parameters @{
                mockScriptPath = $mockScriptPath
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-FunctionDefinitionAst -FullName $mockScriptPath
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'When a script file has parse errors' {
        BeforeAll {
            $definition = '
                function Get-Something
                {
                    return "test1"
                }

                function Get-SomethingElse
                {
                    param
                    (
                        [Parameter()]
                        [System.String]
                        $Param1
                    )

                    return $Param1

            '

            $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
        }

        It 'Should throw an exception' {
            InModuleScope -Parameters @{
                mockScriptPath = $mockScriptPath
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Get-FunctionDefinitionAst -FullName $mockScriptPath } | Should -Throw
            }
        }
    }
}
