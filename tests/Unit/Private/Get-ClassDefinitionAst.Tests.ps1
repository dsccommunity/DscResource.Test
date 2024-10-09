$script:projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$script:projectName = ((Get-ChildItem -Path $script:projectPath\*\*.psd1).Where{
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

Import-Module $script:projectName -Force

InModuleScope $script:projectName {
    Describe 'DscResource.Test\Get-ClassDefinitionAst' -Tag 'Private', 'Get-ClassDefinitionAst' {
        BeforeAll {
            $mockScriptPath = Join-Path -Path $TestDrive -ChildPath 'TestFunctions.ps1'
        }

        Context 'When a script file has function definitions' {
            BeforeAll {
                $definition = '
                    class MyClass
                    {
                        MyClass() {}
                    }

                    class MyClass2
                    {
                        [DscProperty(Key)]
                        [System.String]
                        $Name

                        MyClass2() {}
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
            }

            It 'Should return the correct number of class definitions' {
                $result = Get-FunctionDefinitionAst -FullName $mockScriptPath
                $result | Should -HaveCount 2
            }
        }

        Context 'When a script file has no class definitions' {
            BeforeAll {
                $definition = '
                    $script:variable = 1
                    return $script:variable
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
            }

            It 'Should return $null' {
                $result = Get-ClassDefinitionAst -FullName $mockScriptPath
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'When a script file has a parse error' {
            BeforeAll {
                $definition = '
                    class Mycla {
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
            }

            It 'Should throw and exception' {
                { Get-ClassDefinitionAst -FullName $mockScriptPath } | Should -Throw
            }
        }
    }
}
