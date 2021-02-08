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

Import-Module $ProjectName

InModuleScope $ProjectName {
    $ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    Mock -CommandName Get-Command -MockWith {
        {
            [CmdletBinding()]
            param (
                [Parameter()]
                $Module,

                [Parameter()]
                $FullyQualifiedModule,

                [Parameter()]
                $ProjectPath,

                [Parameter()]
                $Script,

                [Parameter()]
                $TestName,

                [Parameter()]
                $EnableExit,

                [Parameter()]
                $Tag,

                [Parameter()]
                $ExcludeTag,

                [Parameter()]
                $PassThru,

                [Parameter()]
                $CodeCoverage,

                [Parameter()]
                $CodeCoverageOutputFile,

                [Parameter()]
                $CodeCoverageOutputFileFormat,

                [Parameter()]
                $Strict,

                [Parameter()]
                $OutputFile,

                [Parameter()]
                $OutputFormat,

                [Parameter()]
                $Quiet,

                [Parameter()]
                $PesterOption,

                [Parameter()]
                $Show,

                [Parameter()]
                $Settings,

                [Parameter()]
                $MainGitBranch
            )

            return $PSBoundParameters
        }
    }
    Mock -CommandName Get-StructuredObjectFromFile -MockWith { @('noTag') }

    Describe 'Invoke-DscResourceTest Resolving Built Module' {
        Context 'When calling by module name' {
            It 'Should fail when using a missing module' {
                { Invoke-DscResourceTest -Module ModuleThatDontExist } | Should -Throw
            }

            It 'works when using an existing module' {
                {
                    Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing
                } | Should -Not -Throw
                Assert-MockCalled -CommandName Get-Command -Scope It
            }

            It 'Should call Invoke-Pester with correct parameters' {
                $result = Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing
                $result.Script.Path | Should -BeExactly '.'
                $result.Script.Parameters.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                $result.Script.Parameters.keys | Should -HaveCount 11
                $result.Tag | Should -BeExactly 'nothing' `
                    -Because 'When parameter is specified it override defaults & settings'
            }
        }

        Context 'When with alternate MainGitBranch' {
            It 'Should call Invoke-Pester with correct parameters' {
                $result = Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script '.' -Tag nothing -MainGitBranch 'main'
                $result.Script.Path | Should -BeExactly '.'
                $result.Script.Parameters.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                $result.Script.Parameters.keys | Should -HaveCount 11
                $result.Script.Parameters.MainGitBranch | Should -BeExactly 'main' `
                    -Because 'When parameter is specified it override defaults & settings'
                $result.Tag | Should -BeExactly 'nothing' `
                    -Because 'When parameter is specified it override defaults & settings'
            }
        }

        Context 'When calling by module path' {
            It 'Should fail when using a wrong path' {
                {
                    Invoke-DscResourceTest -Module 'C:\MyModuleNameDoesNotExist'
                } | Should -Throw
            }

            Mock -CommandName Import-Module -MockWith {
                param (
                    [Parameter()]
                    $Name,

                    [Parameter()]
                    $FullyQualifiedModule,

                    [Parameter()]
                    $PassThru,

                    [Parameter()]
                    $Force
                )

                return (
                    $PSBoundParameters + @{
                        ModuleBase = 'TestDrive:\'
                        ModuleName = 'MyModule'
                        Path       = 'TestDrive:\MyModule.psd1'
                    }
                )
            }

            It 'Should invoke pester using correct parameters when using an existing module path' {
                $result = Invoke-DscResourceTest -Module 'C:\MyModuleNameDoesNotExist.psd1'
                $result.Script.Parameters.ProjectPath | Should -BeNullOrEmpty
                $result.Script.Parameters.ModuleName | Should -BeExactly 'C:\MyModuleNameDoesNotExist.psd1'
            }
        }

        Context 'When calling by module specification' {
            [Microsoft.PowerShell.Commands.ModuleSpecification] $FQM = @{
                ModuleName    = 'Microsoft.PowerShell.Utility'
                ModuleVersion = '1.0.0.0'
            }
            $result = Invoke-DscResourceTest -FullyQualifiedModule $FQM -Script .
            $result.Script.Path | Should -BeExactly '.'
            $result.Script.Parameters.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
            $result.Script.Parameters.keys | Should -HaveCount 11
        }

        Context 'When calling by project path' {
            $null = Invoke-DscResourceTest -ProjectPath $ProjectPath

            It 'Should call by project path' {
                Assert-MockCalled -CommandName Get-Command -Scope Context
            }
        }
    }

    Describe 'Loading Opt Ins and Opt Outs by Tags' {
        Mock -CommandName Import-Module -MockWith {
            return @{
                ModuleBase = 'TestDrive:\'
                ModuleName = 'MyModule'
                Path       = 'TestDrive:\MyModule.psd1'
                Guid       = 'fd8c76f8-c702-49d0-9da8-f5661c2373bc'
            }
        }

        Mock -CommandName Get-ChildItem -MockWith {
            @{
                FullName = 'C:\dummy.psd1'
            }
        }

        Mock -CommandName Import-PowerShellDataFile -MockWith {
            return @{
                ModuleBase = 'TestDrive:\'
                ModuleName = 'MyModule'
                Path       = 'TestDrive:\MyModule.psd1'
                Guid       = 'fd8c76f8-c702-49d0-9da8-f5661c2373bc'
            }
        }

        Mock -CommandName Get-StructuredObjectFromFile -ParameterFilter {
            $Path -like '*out.json'
        } -MockWith {
            param (
                [Parameter()]
                $Path
            )

            @('noTag', 'ExcludeTag')
        }

        It 'Should override properly the Script parameters for Invoke-Pester' {
            $result = Invoke-DscResourceTest -ProjectPath $PSScriptRoot\..\assets
            Assert-MockCalled Get-Command -Scope Describe
            $result.Script.Parameters.ModuleName | Should -Not -BeExactly 'dummy'
            $result.script.Parameters.Keys | Should -HaveCount 11
            $result.Tag | Should -HaveCount 1
            $result.ExcludeTag | Should -HaveCount 1
        }
    }

    Describe 'Merging settings from Config and params' {
    }

    Describe 'Pester Scripts Parameters' {
        Mock -CommandName Import-Module -MockWith {
            return @{
                ModuleBase = 'TestDrive:\'
                ModuleName = 'MyModule'
                Path       = 'TestDrive:\MyModule.psd1'

            }
        } -ParameterFilter {
            $Name -like '*.psd1'
        }

        It 'Should override properly the Script parameters for Invoke-Pester' {
            $result = Invoke-DscResourceTest -Script @{
                Path       = '.'
                Parameters = @{
                    'ModuleName' = 'dummy'
                }
            } -Module 'Microsoft.PowerShell.Utility'
            $result.Script.Parameters.ModuleName | Should -Not -BeExactly 'dummy'
            $result.script.Parameters.Keys | Should -HaveCount 11
        }
    }
}
