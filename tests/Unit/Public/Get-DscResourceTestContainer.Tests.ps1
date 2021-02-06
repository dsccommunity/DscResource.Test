$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-DscResourceTestContainer' {
        BeforeAll {
            $mockGetDscResourceTestContainerParameters = @{
                ProjectPath       = '.'
                ModuleName        = 'MyDscResourceName'
                DefaultBranch     = 'main'
                SourcePath        = './source'
                ModuleBase        = "./output/MyDscResourceName/*"
            }
        }

        Context 'When only Pester 4 is available' {
            BeforeAll {
                Mock -CommandName Get-Module -MockWith {
                    return @{
                        Version = '4.10.1'
                    }
                }
            }

            It 'Should throw the correct exception' {
                { Get-DscResourceTestContainer @mockGetDscResourceTestContainerParameters } | Should -Throw 'This command requires Pester v5.1.0 or higher to be installed.'
            }
        }

        Context 'When getting Pester 5 HQRM tests script containers' {
            BeforeAll {
                # Must create a stub since this does not exist in Pester 4.
                function New-PesterContainer
                {
                    throw '{0}: StubNotImplemented' -f $MyInvocation.MyCommand
                }

                Mock -CommandName New-PesterContainer
                Mock -CommandName Get-Module -MockWith {
                    return @{
                        Version = '5.1.0'
                    }
                }
            }

            It 'Should call the correct mock' {
                { Get-DscResourceTestContainer @mockGetDscResourceTestContainerParameters } | Should -Not -Throw

                Assert-MockCalled -CommandName 'New-PesterContainer' -Exactly -Times 1 -Scope It
            }
        }
    }

}
