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

Describe 'Initialize-TestEnvironment' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            if ($script:machineOldPSModulePath)
            {
                throw 'The script variable $script:machineOldPSModulePath was already set, cannot run unit test. This should not happen unless the test is run in the context of an integration test.'
            }
        }
    }

    AfterEach {
        InModuleScope -ScriptBlock {
            <#
                Make sure to set this to $null so that the unit tests won't fail.
            #>
            $script:machineOldPSModulePath = $null
        }
    }

    Context 'When initializing the test environment' {
        BeforeDiscovery {
            $testCases = @(
                @{
                    TestType     = 'Unit'
                    ResourceType = 'Mof'
                },

                @{
                    TestType     = 'Unit'
                    ResourceType = 'Class'
                },

                @{
                    TestType     = 'Integration'
                    ResourceType = 'Mof'
                }
            )
        }

        BeforeAll {
            $mockDscModuleName = 'TestModule'
            $mockDscResourceName = 'TestResource'

            Mock -CommandName 'Set-PSModulePath'
            Mock -CommandName 'Clear-DscLcmConfiguration'
            Mock -CommandName 'Set-ExecutionPolicy'
            Mock -CommandName 'Import-Module'
            Mock -CommandName 'New-DscSelfSignedCertificate'
            Mock -CommandName 'Initialize-DscTestLcm'

            Mock -CommandName 'Split-Path' -MockWith {
                return $TestDrive
            }

            Mock -CommandName 'Get-ExecutionPolicy' -MockWith {
                'Restricted'
            }

            Mock -CommandName Import-Module -MockWith {
                param
                (
                    $Name
                )
                @{
                    ModuleBase = $TestDrive
                    Name       = $Name
                }
            }

            <#
                    Build the mocked resource folder and file structure for both
                    mof- and class-based resources.
                #>
            $filePath = Join-Path -Path $TestDrive -ChildPath ('{0}.psd1' -f $mockDscModuleName)
            'test manifest' | Out-File -FilePath $filePath -Encoding ascii

            $mockDscResourcesPath = Join-Path -Path $TestDrive -ChildPath 'DSCResources'
            $mockDscClassResourcesPath = Join-Path -Path $TestDrive -ChildPath 'DSCClassResources'
            New-Item -Path $mockDscResourcesPath -ItemType Directory
            New-Item -Path $mockDscClassResourcesPath -ItemType Directory

            $mockMofResourcePath = Join-Path -Path $mockDscResourcesPath -ChildPath $mockDscResourceName
            $mockClassResourcePath = Join-Path -Path $mockDscClassResourcesPath -ChildPath $mockDscResourceName
            New-Item -Path $mockMofResourcePath -ItemType Directory
            New-Item -Path $mockClassResourcePath -ItemType Directory

            $filePath = Join-Path -Path $mockMofResourcePath -ChildPath ('{0}.psm1' -f $mockDscResourceName)
            'test mof resource module file' | Out-File -FilePath $filePath -Encoding ascii
            $filePath = Join-Path -Path $mockClassResourcePath -ChildPath ('{0}.psm1' -f $mockDscResourceName)
            'test class resource module file' | Out-File -FilePath $filePath -Encoding ascii

            InModuleScope -Parameters @{
                mockDscModuleName   = $mockDscModuleName
                mockDscResourceName = $mockDscResourceName
            } -ScriptBlock {
                $script:mockDscModuleName = $mockDscModuleName
                $script:mockDscResourceName = $mockDscResourceName
            }
        }

        It 'Should initialize without throwing when test type is <TestType> and resource type is <ResourceType>' -TestCases $testCases {
            InModuleScope -Parameters $_ -ScriptBlock {
                Set-StrictMode -Version 1.0

                $initializeTestEnvironmentParameters = @{
                    Module          = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = $TestType
                    ResourceType    = $ResourceType
                }

                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Not -Throw
            }

            Should -Invoke -CommandName Split-Path -Exactly -Times 2 -Scope It
            Should -Invoke -CommandName Import-Module -Exactly -Times 2 -Scope It
            Should -Invoke -CommandName Set-PSModulePath -ParameterFilter {
                $PesterBoundParameters.ContainsKey('Machine') -eq $false
            } -Exactly -Times 1 -Scope It

            if ($TestEnvironment.TestType -eq 'Integration')
            {
                Should -Invoke -CommandName Clear-DscLcmConfiguration -Exactly -Times 1 -Scope It
                Should -Invoke -CommandName Set-PSModulePath -ParameterFilter {
                    $PesterBoundParameters.ContainsKey('Machine') -eq $true
                } -Exactly -Times 1 -Scope It

                if (($PSEdition -eq 'Desktop' -or $IsWindows) -and
                        ($Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())) -and
                    $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                )
                {
                    Should -Invoke -CommandName Initialize-DscTestLcm -Exactly -Times 1 -Scope It
                    Should -Invoke -CommandName New-DscSelfSignedCertificate -Exactly -Times 1 -Scope It
                }
            }

            Should -Invoke -CommandName Get-ExecutionPolicy
            Should -Invoke -CommandName Set-ExecutionPolicy -Exactly -Times 0 -Scope It
        }

        Context 'When setting specific execution policy' {
            It 'Should initialize without throwing when test type is <TestType> and resource type is <ResourceType>' -TestCases $testCases {
                InModuleScope -Parameters $_ -ScriptBlock {
                    #Set-StrictMode -Version 1.0

                    $initializeTestEnvironmentParameters = @{
                        Module                 = $mockDscModuleName
                        DSCResourceName        = $mockDscResourceName
                        TestType               = $TestType
                        ResourceType           = $ResourceType
                        ProcessExecutionPolicy = 'Unrestricted'
                        MachineExecutionPolicy = 'Unrestricted'
                    }

                    { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Not -Throw
                }

                Should -Invoke -CommandName 'Get-ExecutionPolicy'
                Should -Invoke -CommandName 'Set-ExecutionPolicy'
            }
        }
    }


    Context 'When there is no module manifest file' {
        BeforeAll {
            Mock -CommandName 'Import-Module' -MockWith {
                Throw 'Import Module will throw because the module does not exist'
            }
        }

        It 'Should throw the correct error' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $initializeTestEnvironmentParameters = @{
                    DSCModuleName   = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = 'Unit'
                }

                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Throw
            }

            Should -Invoke -CommandName 'Import-Module' -Exactly -Times 1 -Scope It
        }
    }
}
