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
                & "$PSScriptRoot/../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
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

Describe 'Wait-ForIdleLcm' -Tag 'Public' {
    BeforeAll {
        <#
            Stub for Get-DscLocalConfigurationManager since it is not available
            cross-platform.
        #>
        function Get-DscLocalConfigurationManager
        {
            [CmdletBinding()]
            param ()

            throw '{0}: StubNotImplemented' -f $MyInvocation.MyCommand
        }
    }

    AfterAll {
        Remove-Item -Path 'function:Get-DscLocalConfigurationManager'
    }

    Context 'When the LCM is idle' {
        BeforeAll {
            Mock -CommandName Start-Sleep
            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                return @{
                    LCMState = 'Idle'
                }
            }
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm } | Should -Not -Throw

            Should -Invoke -CommandName Get-DscLocalConfigurationManager -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 0 -Scope It
        }
    }

    Context 'When waiting for the LCM to become idle' {
        BeforeAll {
            Mock -CommandName Start-Sleep -MockWith {
                $script:mockStartSleepWasCalled = $true
            }

            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                $mockLcmState = if ($script:mockStartSleepWasCalled)
                {
                    @{
                        LCMState = 'Idle'
                    }
                }
                else
                {
                    @{
                        LCMState = 'Busy'
                    }
                }

                return $mockLcmState
            }
        }

        BeforeEach {
            $script:mockStartSleepWasCalled = $false
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm } | Should -Not -Throw

            Should -Invoke -CommandName Get-DscLocalConfigurationManager -Exactly -Times 2 -Scope It
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 1 -Scope It
        }
    }

    Context 'When timeout is reached when waiting for the LCM to become idle' {
        BeforeAll {
            <#
                We must not mock Start-Sleep in this test, if we do the loop will
                run several thousands of times.
            #>

            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                return @{
                    LCMState = 'Busy'
                }
            }
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm -Timeout '00:00:08' } | Should -Not -Throw

            Should -Invoke -CommandName Get-DscLocalConfigurationManager -Times 3 -Scope It
        }
    }

    Context 'When the LCM is idle an the LCM should be cleared after' {
        BeforeAll {
            Mock -CommandName Start-Sleep
            Mock -CommandName Clear-DscLcmConfiguration
            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                return @{
                    LCMState = 'Idle'
                }
            }
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm -Clear } | Should -Not -Throw

            Should -Invoke -CommandName Get-DscLocalConfigurationManager -Exactly -Times 1 -Scope It
            Should -Invoke -CommandName Start-Sleep -Exactly -Times 0 -Scope It
            Should -Invoke -CommandName Clear-DscLcmConfiguration -Exactly -Times 1 -Scope It
        }
    }
}
