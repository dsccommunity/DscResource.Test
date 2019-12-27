$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Initialize-TestEnvironment' {
        Context 'When initializing the test environment' {
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
                        Name = $Name
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

            It 'Should initializing without throwing when test type is <TestType> and resource type is <ResourceType>' -TestCases $testCases {
                param
                (
                    # String containing the test type; Unit or Integration.
                    [Parameter()]
                    [System.String]
                    $TestType,

                    # String containing a resource type; Mof or Class.
                    [Parameter()]
                    [System.String]
                    $ResourceType
                )

                $initializeTestEnvironmentParameters = @{
                    Module          = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = $TestType
                    ResourceType    = $ResourceType
                }

                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Split-Path' -Exactly -Times 2 -Scope It
                Assert-MockCalled -CommandName 'Import-Module' -Exactly -Times 2 -Scope It
                Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                    $PSBoundParameters.ContainsKey('Machine') -eq $false
                } -Exactly -Times 1 -Scope It

                if ($TestEnvironment.TestType -eq 'Integration')
                {
                    Assert-MockCalled -CommandName 'Clear-DscLcmConfiguration' -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName 'Set-PSModulePath' -ParameterFilter {
                        $PSBoundParameters.ContainsKey('Machine') -eq $true
                    } -Exactly -Times 1 -Scope It

                    if (($IsWindows -or $PSEdition -eq 'Desktop') -and
                        ($Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())) -and
                        $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                    )
                    {
                        Assert-MockCalled -CommandName 'Initialize-DscTestLcm' -Exactly -Times 1 -Scope It
                        Assert-MockCalled -CommandName 'New-DscSelfSignedCertificate' -Exactly -Times 1 -Scope It
                    }
                }

                Assert-MockCalled -CommandName 'Get-ExecutionPolicy' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 0 -Scope It
            }

            Context 'When setting specific execution policy' {
                It 'Should initializing without throwing when test type is <TestType> and resource type is <ResourceType>' -TestCases $testCases {
                    param
                    (
                        # String containing the test type; Unit or Integration.
                        [Parameter()]
                        [System.String]
                        $TestType,

                        # String containing a resource type; Mof or Class.
                        [Parameter()]
                        [System.String]
                        $ResourceType
                    )

                    $initializeTestEnvironmentParameters = @{
                        Module                 = $mockDscModuleName
                        DSCResourceName        = $mockDscResourceName
                        TestType               = $TestType
                        ResourceType           = $ResourceType
                        ProcessExecutionPolicy = 'Unrestricted'
                        MachineExecutionPolicy = 'Unrestricted'
                    }

                    { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName 'Get-ExecutionPolicy' -Exactly -Times 1 -Scope It
                    Assert-MockCalled -CommandName 'Set-ExecutionPolicy' -Exactly -Times 1 -Scope It
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
                $initializeTestEnvironmentParameters = @{
                    DSCModuleName   = $mockDscModuleName
                    DSCResourceName = $mockDscResourceName
                    TestType        = 'Unit'
                }

                { Initialize-TestEnvironment @initializeTestEnvironmentParameters } | Should -Throw

                Assert-MockCalled -CommandName 'Import-Module' -Exactly -Times 1 -Scope It
            }
        }
    }
}
