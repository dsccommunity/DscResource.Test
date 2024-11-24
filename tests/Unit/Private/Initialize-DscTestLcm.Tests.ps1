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

    InModuleScope -ScriptBlock {
        # Stub of the generated configuration so it can be mocked.
        function script:LocalConfigurationManagerConfiguration
        {
        }
    }
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Initialize-DscTestLcm' -Skip:(($PSVersionTable.PSEdition -eq 'Core') -or ($IsMacOS -or $IsLinux)) {
    BeforeAll {
        Mock -CommandName New-Item
        Mock -CommandName Remove-Item
        Mock -CommandName Invoke-Command
        Mock -CommandName Set-DscLocalConfigurationManager

        Mock -CommandName LocalConfigurationManagerConfiguration
    }

    Context 'When Local Configuration Manager should have consistency disabled' {
        BeforeAll {
            $expectedConfigurationMetadata = '
                Configuration LocalConfigurationManagerConfiguration
                {
                    LocalConfigurationManager
                    {
                        ConfigurationMode = ''ApplyOnly''
                    }
                }
            '

            # Truncating everything to one line so easier to compare.
            $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
        }

        It 'Should call Invoke-Command with the correct configuration' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Initialize-DscTestLcm -DisableConsistency } | Should -Not -Throw
            }

            Should -Invoke -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
            } -Exactly -Times 1
            Should -Invoke -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
        }
    }

    Context 'When Local Configuration Manager should have consistency disabled' {
        BeforeAll {
            $env:DscCertificateThumbprint = '1111111111111111111111111111111111111111'

            $expectedConfigurationMetadata = "
                Configuration LocalConfigurationManagerConfiguration
                {
                    LocalConfigurationManager
                    {
                        CertificateId = '$($env:DscCertificateThumbprint)'
                    }
                }
            "

            # Truncating everything to one line so easier to compare.
            $expectedConfigurationMetadataOneLine = $expectedConfigurationMetadata -replace '[ \r\n]'
        }

        AfterAll {
            Remove-Item -Path 'env:DscCertificateThumbprint' -Force
        }

        It 'Should call Invoke-Command with the correct configuration' {
            InModuleScope -ScriptBlock {
                Set-StrictMode -Version 1.0

                { Initialize-DscTestLcm -Encrypt } | Should -Not -Throw
            }

            Should -Invoke -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
            } -Exactly -Times 1
            Should -Invoke -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1 -Scope It
        }
    }
}
