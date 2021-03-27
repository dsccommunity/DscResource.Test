$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try
            {
                Test-ModuleManifest $_.FullName -ErrorAction Stop
            }
            catch
            {
                $false
            } )
    }).BaseName

Import-Module -Name $ProjectName -Force

Describe 'Wait-ForIdleLcm' -Tag 'WaitForIdleLcm' {
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
            Mock -CommandName Start-Sleep -ModuleName $ProjectName
            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                return @{
                    LCMState = 'Idle'
                }
            } -ModuleName $ProjectName
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm } | Should -Not -Throw

            Assert-MockCalled -CommandName Get-DscLocalConfigurationManager -Exactly -Times 1 -Scope It -ModuleName $ProjectName
            Assert-MockCalled -CommandName Start-Sleep -Exactly -Times 0 -Scope It -ModuleName $ProjectName
        }
    }

    Context 'When waiting for the LCM to become idle' {
        BeforeAll {
            Mock -CommandName Start-Sleep -MockWith {
                $script:mockStartSleepWasCalled = $true
            } -ModuleName $ProjectName

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
            } -ModuleName $ProjectName
        }

        BeforeEach {
            $script:mockStartSleepWasCalled = $false
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm } | Should -Not -Throw

            Assert-MockCalled -CommandName Get-DscLocalConfigurationManager -Exactly -Times 2 -Scope It -ModuleName $ProjectName
            Assert-MockCalled -CommandName Start-Sleep -Exactly -Times 1 -Scope It -ModuleName $ProjectName
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
            } -ModuleName $ProjectName
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm -Timeout 8 } | Should -Not -Throw

            Assert-MockCalled -CommandName Get-DscLocalConfigurationManager -Times 3 -Scope It -ModuleName $ProjectName
        }
    }

    Context 'When the LCM is idle an the LCM should be cleared after' {
        BeforeAll {
            Mock -CommandName Start-Sleep -ModuleName $ProjectName
            Mock -CommandName Clear-DscLcmConfiguration -ModuleName $ProjectName
            Mock -CommandName Get-DscLocalConfigurationManager -MockWith {
                return @{
                    LCMState = 'Idle'
                }
            } -ModuleName $ProjectName
        }

        It 'Should not throw and call the expected mocks' {
            { Wait-ForIdleLcm -Clear } | Should -Not -Throw

            Assert-MockCalled -CommandName Get-DscLocalConfigurationManager -Exactly -Times 1 -Scope It -ModuleName $ProjectName
            Assert-MockCalled -CommandName Start-Sleep -Exactly -Times 0 -Scope It -ModuleName $ProjectName
            Assert-MockCalled -CommandName Clear-DscLcmConfiguration -Exactly -Times 1 -Scope It -ModuleName $ProjectName
        }
    }
}
