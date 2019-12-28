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

Import-Module $ProjectName -Force

if ($isLinux -or $isMacOS)
{
    Write-Warning -Message 'DSC configuration parsing is not currently supported on Linux or MacOS. Skipping test.'
    return
}

InModuleScope $ProjectName {
    Describe 'DscResource.GalleryDeploy\Test-ConfigurationName' -Tag 'WindowsOnly' {
        BeforeAll {
            $mockScriptPath = Join-Path -Path $TestDrive -ChildPath '99-TestConfig'
        }

        Context 'When a script file has the correct name' {
            BeforeAll {
                $definition = '
                Configuration TestConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return true' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $true
            }
        }

        Context 'When a script file has the different name than the configuration name' {
            BeforeAll {
                $definition = '
                Configuration WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }

        Context 'When the configuration name starts with a number' {
            BeforeAll {
                $definition = '
                Configuration 1WrongConfig
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should throw the correct error' {
                $errorMessage = 'The configuration name ''1WrongConfig'' is not valid.'
                { Test-ConfigurationName -Path $mockScriptPath } | Should -Throw $errorMessage
            }
        }

        Context 'When the configuration name does not end with a letter or a number' {
            BeforeAll {
                $definition = '
                Configuration WrongConfig_
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }

        Context 'When the configuration name contain other characters than only letters, numbers, and underscores' {
            BeforeAll {
                $definition = '
                Configuration Wrong-Config
                {
                }
            '

                $definition | Out-File -FilePath $mockScriptPath -Encoding utf8 -Force
            }

            It 'Should return false' {
                $result = Test-ConfigurationName -Path $mockScriptPath
                $result | Should -Be $false
            }
        }
    }
}
