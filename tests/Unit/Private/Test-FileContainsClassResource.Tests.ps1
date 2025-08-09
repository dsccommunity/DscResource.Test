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

Describe 'Test-FileContainsClassResource' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockResourceName1 = 'TestResourceName1'
            $script:mockResourceName2 = 'TestResourceName2'

            $script:scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }
    }

    Context 'When module file contains class-based resources' {
        It 'Should return $true when DscResource attribute has no parameters' {
            InModuleScope -ScriptBlock {
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
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -BeTrue
            }
        }

        It 'Should return $true when DscResource attribute has parameters' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                [DscResource(RunAsCredential = 'NotSupported')]
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
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When module file does not contain class-based resources' {
        It 'Should return $false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                "
                function $mockResourceName1
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -BeFalse
            }
        }
    }

    Context 'When module file has parsing errors' {
        It 'Should throw an exception for syntax errors' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                # Create a file with syntax error
                "
                [DscResource()]
                class $mockResourceName1
                {
                    # Missing closing brace
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                { Test-FileContainsClassResource -FilePath $scriptPath } | Should -Throw -ExpectedMessage "Parse error in file*"
            }
        }

        It 'Should throw an exception for DSC validation errors' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                # Create a file with DSC validation error (invalid attribute property)
                "
                [DscResource(InvalidProperty = 'Test')]
                class $mockResourceName1
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                { Test-FileContainsClassResource -FilePath $scriptPath } | Should -Throw -ExpectedMessage "Parse error in file*"
            }
        }
    }
}
