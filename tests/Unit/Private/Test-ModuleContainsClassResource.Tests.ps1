$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {

    Describe 'Test-ModuleContainsClassResource' {
        BeforeAll {
            $filePath = (Join-Path -Path $TestDrive -ChildPath 'test.psm1')
            'testfile' | Out-File -FilePath $filePath -Encoding ascii
        }

        Context 'When a module contains class resources' {
            BeforeEach {
                Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                    return $true
                }
            }

            It 'Should return $true' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeTrue

                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a module does not contain a class resource' {
            BeforeEach {
                Mock -CommandName 'Test-FileContainsClassResource' -MockWith {
                    return $false
                }
            }

            It 'Should return $false' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeFalse

                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 1 -Scope It
            }
        }

        Context 'When a module does not contain any resources' {
            BeforeEach {
                Mock -CommandName 'Get-Psm1FileList'
                Mock -CommandName 'Test-FileContainsClassResource'
            }

            It 'Should return $false' {
                $result = Test-ModuleContainsClassResource -ModulePath $TestDrive
                $result | Should -BeFalse

                Assert-MockCalled -CommandName 'Get-Psm1FileList' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Test-FileContainsClassResource' -Exactly -Times 0 -Scope It
            }
        }
    }

}
