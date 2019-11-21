$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-ClassResourceNameFromFile' {
        BeforeAll {
            $mockResourceName1 = 'TestResourceName1'
            $mockResourceName2 = 'TestResourceName2'

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When querying for the name of a class-based resource' {
            It 'Should return the correct name of the resource' {
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

                $result = Get-ClassResourceNameFromFile -FilePath $scriptPath
                $result.Count | Should -Be 2
                $result[0] | Should -Be $mockResourceName1
                $result[1] | Should -Be $mockResourceName2
            }
        }
    }
}