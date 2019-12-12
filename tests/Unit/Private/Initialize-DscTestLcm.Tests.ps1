$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {

    if ($PSVersionTable.PSVersion.Major -gt 5)
    {
        function Set-DscLocalConfigurationManager {}
    }
    Describe 'Initialize-DscTestLcm' {
        BeforeAll {
            Mock -CommandName New-Item
            Mock -CommandName Remove-Item
            Mock -CommandName Invoke-Command
            Mock -CommandName Set-DscLocalConfigurationManager

            # Stub of the generated configuration so it can be mocked.
            function LocalConfigurationManagerConfiguration
            {
            }

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
                { Initialize-DscTestLcm -DisableConsistency } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
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
                { Initialize-DscTestLcm -Encrypt } | Should -Not -Throw

                Assert-MockCalled -CommandName Invoke-Command -ParameterFilter {
                    ($ScriptBlock.ToString() -replace '[ \r\n]') -eq $expectedConfigurationMetadataOneLine
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Set-DscLocalConfigurationManager -Exactly -Times 1
            }
        }
    }
}
