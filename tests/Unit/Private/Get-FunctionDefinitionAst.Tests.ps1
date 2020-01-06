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
    Describe 'DscResource.GalleryDeploy\Get-FunctionDefinitionAst' -Tag 'Get-FunctionDefinitionAst' {
        BeforeAll {
            $mockScriptPath = Join-Path -Path $TestDrive -ChildPath 'TestFunctions.ps1'
        }

        Context 'When a script file has function definitions' {
            BeforeAll {
                $definition = '
                    function Get-Something
                    {
                        return "test1"
                    }

                    function Get-SomethingElse
                    {
                        param
                        (
                            [Parameter()]
                            [System.String]
                            $Param1
                        )

                        return $Param1
                    }
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
            }

            It 'Should return the correct number of function definitions' {
                $result = Get-FunctionDefinitionAst -FullName $mockScriptPath
                $result | Should -HaveCount 2
            }
        }

        Context 'When a script file has no function definitions' {
            BeforeAll {
                $definition = '
                    $script:variable = 1
                    return $script:variable
                '

                $definition | Out-File -FilePath $mockScriptPath -Encoding 'ascii' -Force
            }

            It 'Should return $null' {
                $result = Get-FunctionDefinitionAst -FullName $mockScriptPath
                $result | Should -BeNullOrEmpty
            }
        }
    }
}
