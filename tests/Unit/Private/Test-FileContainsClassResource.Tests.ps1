$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'TestHelper\Test-FileContainsClassResource' {
        BeforeAll {
            $mockResourceName1 = 'TestResourceName1'
            $mockResourceName2 = 'TestResourceName2'

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When module file contain class-based resources' {
            It 'Should return $true' {
                "
                [DscResource()]
                class $mockResourceName1
                {
                }

                [DscResource()]
                class $mockResourceName2
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -BeTrue
            }
        }

        Context 'When module file does not contain class-based resources' {
            It 'Should return $false' {
                "
                function $mockResourceName1
                {
                }
                " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Test-FileContainsClassResource -FilePath $scriptPath
                $result | Should -BeFalse
            }
        }
    }
}
