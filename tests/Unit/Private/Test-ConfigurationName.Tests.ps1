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

Describe 'DscResource.GalleryDeploy\Test-ConfigurationName' -Tag 'WindowsOnly' -Skip:($isLinux -or $isMacOS) {
    BeforeAll {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $script:mockScriptPath = Join-Path -Path $TestDrive -ChildPath '99-TestConfig'
        }
    }

    Context 'When a script file has the correct name' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration TestConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When a script file has the correct name but is a LCM meta configuration' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                [DSCLocalConfigurationManager()]
                Configuration TestConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return true' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -BeTrue
            }
        }
    }

    Context 'When a script file has the different name than the configuration name' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -BeFalse
            }
        }
    }

    Context 'When the configuration name starts with a number' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration 1WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should throw the correct error' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $errorMessage = 'The configuration name ''1WrongConfig'' is not valid.'

                { Test-ConfigurationName -Path $mockScriptPath } | Should -Throw -ExpectedMessage ('*' + $errorMessage + '*')
            }
        }
    }

    Context 'When the configuration name does not end with a letter or a number' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration WrongConfig_
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return false' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -BeFalse
            }
        }
    }

    Context 'When the configuration name contain other characters than only letters, numbers, and underscores' {
        BeforeAll {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $definition = '
                Configuration Wrong-Config
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }
        }

        It 'Should return false' -Skip:($PSVersionTable.PSVersion -lt [System.Version] '5.1') {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -BeFalse
            }
        }
    }
}
