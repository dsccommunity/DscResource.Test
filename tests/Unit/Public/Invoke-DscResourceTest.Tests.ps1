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

Describe 'Invoke-DscResourceTest' -Tag 'Public' {
    BeforeAll {
        Mock -CommandName Get-Command -MockWith {
            return 'Invoke-Pester'
        }

        Mock -CommandName Get-StructuredObjectFromFile -MockWith { @('noTag') }

        Mock -CommandName Invoke-Pester -MockWith {
            return $PesterBoundParameters
        }
    }

    Context 'When Resolving Built Module' {
        Context 'When calling by module name' {
            It 'Should fail when using a missing module' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    { Invoke-DscResourceTest -Module ModuleThatDoesNotExist } | Should -Throw -ExpectedMessage 'The specified module ''ModuleThatDoesNotExist'' was not loaded because no valid module file was found in any module directory.'
                }
            }

            It 'Should work when using an existing module' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    { Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing } | Should -Not -Throw
                }

                Should -Invoke -CommandName Get-Command -Scope It -Exactly -Times 1
                Should -Invoke -CommandName Invoke-Pester -Scope It -Exactly -Times 1
            }

            It 'Should call Invoke-Pester with correct parameters' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    # In PSBoundParameters the parameters used by the function are the last object returned
                    $result = (Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing)[-1]

                    $result.Path | Should -BeExactly '.'
                    $result.Container.Count | Should -Be 11
                    $result.Container[0].Data.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                    #$result.Tag | Should -BeExactly 'nothing' -Because 'When parameter is specified it override defaults & settings'
                }

                Should -Invoke -CommandName Get-Command -Scope It -Exactly -Times 1
                Should -Invoke -CommandName Invoke-Pester -Scope It -Exactly -Times 1
            }
        }

        Context 'When with alternate MainGitBranch' {
            It 'Should call Invoke-Pester with correct parameters' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    # In PSBoundParameters the parameters used by the function are the last object returned
                    $result = (Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing -MainGitBranch 'main')[-1]

                    $result.Path | Should -BeExactly '.'
                    $result.Container.Count | Should -Be 11
                    $result.Container[0].Data.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                    $result.Container[0].Data.MainGitBranch | Should -BeExactly 'main' `
                        -Because 'When parameter is specified it override defaults & settings'
                    # $result.Tag | Should -BeExactly 'nothing' `
                    #     -Because 'When parameter is specified it override defaults & settings'
                }

                Should -Invoke -CommandName Get-Command -Scope It -Exactly -Times 1
                Should -Invoke -CommandName Invoke-Pester -Scope It -Exactly -Times 1
            }
        }

        Context 'When calling by module path' {
            BeforeAll {
                Mock -CommandName Import-Module -MockWith {
                    return (
                        @{
                            ModuleBase = 'TestDrive:\'
                            Name       = 'C:\MyModuleNameDoesNotExist.psd1'
                            Path       = 'TestDrive:\MyModule.psd1'
                        }
                    )
                }
            }

            It 'Should fail when using a wrong path' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    # { Invoke-DscResourceTest -Module 'C:\MyModuleNameDoesNotExist' } | Should -Throw
                }
            }

            It 'Should invoke pester using correct parameters when using an existing module path' {
                InModuleScope -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    $result = Invoke-DscResourceTest -Module 'C:\MyModuleNameDoesNotExist.psd1'

                    $result.Container[0].Data.ProjectPath | Should -BeNullOrEmpty
                    $result.Container[0].Data.ModuleName | Should -BeExactly 'C:\MyModuleNameDoesNotExist.psd1'
                }
            }
        }

        # Context 'When calling by module specification' {
        #     It 'Should invoke pester using the correct parameters' {
        #         InModuleScope -ScriptBlock {
        #             Set-StrictMode -Version 1.0

        #             [Microsoft.PowerShell.Commands.ModuleSpecification] $FQM = @{
        #                 ModuleName    = 'Microsoft.PowerShell.Utility'
        #                 ModuleVersion = '1.0.0.0'
        #             }

        #             $result = (Invoke-DscResourceTest -FullyQualifiedModule $FQM -Script .)[-1]

        #             $result.Path | Should -BeExactly '.'
        #             $result.Container[0].Data.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
        #             $result.Container | Should -HaveCount 11
        #         }
        #     }
        # }

        Context 'When calling by project path' {
            It 'Should call by project path' {
                InModuleScope -Parameters @{
                    MockProjectPath = $ProjectPath
                } -ScriptBlock {
                    Set-StrictMode -Version 1.0

                    $null = Invoke-DscResourceTest -ProjectPath $MockProjectPath
                }

                Should -Invoke -CommandName Get-Command -Scope It -Exactly -Times 1
            }
        }
    }

    Context 'Loading Opt Ins and Opt Outs by Tags' {
        BeforeAll {
            Mock -CommandName Import-Module -MockWith {
                return @{
                    ModuleBase = 'TestDrive:\'
                    Name       = 'MyModule'
                    Path       = 'TestDrive:\MyModule.psd1'
                    Guid       = 'fd8c76f8-c702-49d0-9da8-f5661c2373bc'
                }
            }

            Mock -CommandName Get-ChildItem -MockWith {
                @{
                    FullName = 'C:\dummy.psd1'
                }
            }

            Mock -CommandName Import-PowerShellDataFile -MockWith {
                return @{
                    Guid = 'fd8c76f8-c702-49d0-9da8-f5661c2373bc'
                }
            }

            Mock -CommandName Get-StructuredObjectFromFile -ParameterFilter {
                $Path -like '*out.json'
            } -MockWith {
                param (
                    [Parameter()]
                    $Path
                )

                @('noTag', 'ExcludeTag')
            }
        }

        It 'Should override properly the Script parameters for Invoke-Pester' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = (Invoke-DscResourceTest -ProjectPath $PSScriptRoot\..\assets)[-1]

                $result.Container[0].Data.ModuleName | Should -Not -BeExactly 'dummy'
                $result.Container.Count | Should -Be 11
                #$result.Tag | Should -HaveCount 1
                #$result.ExcludeTag | Should -HaveCount 1
            }

            Should -Invoke Get-Command -Scope It -Exactly -Times 1
            Should -Invoke Import-PowerShellDataFile -Scope It -Exactly -Times 1
            Should -Invoke Get-StructuredObjectFromFile -Scope It -Exactly -Times 2
        }
    }

    # Context 'Merging settings from Config and params' {
    # }

    Context 'Pester Scripts Parameters' {
        BeforeAll {
            Mock -CommandName Import-Module -MockWith {
                return @{
                    ModuleBase = 'TestDrive:\'
                    Name       = 'MyModule'
                    Path       = 'TestDrive:\MyModule.psd1'
                }
            } -ParameterFilter {
                $Name -like '*.psd1'
            }
        }

        It 'Should override properly the Script parameters for Invoke-Pester' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Invoke-DscResourceTest -Script @{
                    Path       = '.'
                    Parameters = @{
                        'ModuleName' = 'dummy'
                    }
                } -Module 'Microsoft.PowerShell.Utility'

                $result.Container[0].Data.ModuleName | Should -Not -BeExactly 'dummy'
                $result.Container.Count | Should -Be 11
            }
        }
    }
}
