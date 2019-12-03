$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName

Import-Module $ProjectName

InModuleScope $ProjectName {
    $ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    mock Get-Command -MockWith {
        {
            param(
                 $Module
                ,$FullyQualifiedModule
                ,$ProjectPath
                ,$Script
                ,$TestName
                ,$EnableExit
                ,$Tag
                ,$ExcludeTag
                ,$PassThru
                ,$CodeCoverage
                ,$CodeCoverageOutputFile
                ,$CodeCoverageOutputFileFormat
                ,$Strict
                ,$OutputFile
                ,$OutputFormat
                ,$Quiet
                ,$PesterOption
                ,$Show
                ,$Settings
                ,$Verbose
                ,$Debug
                ,$ErrorAction
                ,$WarningAction
                ,$InformationAction
                ,$ErrorVariable
                ,$WarningVariable
                ,$InformationVariable
                ,$OutVariable
                ,$OutBuffer
                ,$PipelineVariable
            )
            return $PSBoundParameters
        }
    }
    mock Get-StructuredObjectFromFile -MockWith { @('noTag') }

    Describe 'Invoke-DscResourceTest Resolving Built Module' {

        Context 'Calling By Module name' {

            It 'fails when using a missing module' {
                {Invoke-DscResourceTest -Module ModuleThatDontExist } | Should -Throw
            }

            It 'works when using an existing module' {
                { Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script "." -Tag nothing } | Should -Not -Throw
                Assert-MockCalled -CommandName Get-Command -Scope It
            }

            It 'Calls Invoke-Pester with correct parameters' {
                $result = Invoke-DscResourceTest -Module Microsoft.PowerShell.Utility -Script "." -Tag nothing
                $result.Script.Path | Should -BeExactly '.'
                $result.Script.Parameters.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                $result.Script.Parameters.keys | Should -HaveCount 10
                $result.Tag | Should -BeExactly 'nothing' `
                                -Because 'When parameter is specified it override defaults & settings'
            }
        }

        Context 'Calling by Module Path' {

            It 'Fails when using a wrong path' {
                {Invoke-DscResourceTest -Module "C:\MyModuleNameDoesNotExist"} | Should -Throw
            }

            mock Import-Module -MockWith {
                param (
                    $Name,
                    $FullyQualifiedModule
                )
                return ($PSBoundParameters + @{
                    ModuleBase = 'TestDrive:\'
                    ModuleName = 'MyModule'
                    Path       = 'TestDrive:\MyModule.psd1'
                })
            }

            It 'Invokes Pester using correct parameters when using an existing Module Path' {
                $result = Invoke-DscResourceTest -Module "C:\MyModuleNameDoesNotExist.psd1"
                $result.Script.Parameters.ProjectPath | Should -BeNullOrEmpty
                $result.Script.Parameters.ModuleName  | Should -BeExactly 'C:\MyModuleNameDoesNotExist.psd1'
            }
        }

        Context 'Calling by Module Specification' {
            [Microsoft.PowerShell.Commands.ModuleSpecification]$FQM = @{
                ModuleName = 'Microsoft.PowerShell.Utility'
                ModuleVersion = '1.0.0.0'
            }
            $result = Invoke-DscResourceTest -FullyQualifiedModule $FQM -Script .
            $result.Script.Path | Should -BeExactly '.'
                $result.Script.Parameters.ModuleName | Should -BeExactly 'Microsoft.PowerShell.Utility'
                $result.Script.Parameters.keys | Should -HaveCount 10

        }

        Context 'Calling by Project Path' {
            $null = Invoke-DscResourceTest -ProjectPath $ProjectPath
            # mock Import-Module -MockWith {
            #     return @{
            #         ModuleBase = 'TestDrive:\'
            #         ModuleName = 'MyModule'
            #         Path       = 'TestDrive:\MyModule.psd1'
            #     }
            # } -ParameterFilter {$Name -like '*.psd1'}


            It 'Calls by Project path' {
                Assert-MockCalled -CommandName Get-Command -Scope Context
                # Assert-MockCalled -CommandName Import-Module -Scope Context
            }
        }
    }

    Describe 'Loading Opt Ins and Opt Outs by Tags' {
        mock Import-Module -MockWith {
            return @{
                ModuleBase = 'TestDrive:\'
                ModuleName = 'MyModule'
                Path       = 'TestDrive:\MyModule.psd1'
            }
        }
        mock Get-ChildItem -MockWith {'C:\dummy.psd1'}


        Mock Get-StructuredObjectFromFile -ParameterFilter { $Path -like '*out.json' } -MockWith {
            param
            (
                $Path
            )
            @('noTag', 'ExcludeTag')
        }

        It 'overrides properly the Script parameters for Invoke-Pester' {
            $result = Invoke-DscResourceTest -ProjectPath $PSScriptRoot\..\assets
            Assert-MockCalled Get-Command -Scope Describe
            $result.Script.Parameters.ModuleName  | Should -Not -BeExactly 'dummy'
            $result.script.Parameters.Keys | Should -HaveCount 10
            $result.Tag | Should -HaveCount 1
            $result.ExcludeTag | Should -HaveCount 1
        }

    }

    Describe 'Merging settings from Config and params' {

    }

    Describe 'Pester Scripts Parameters' {
        mock Import-Module -MockWith {
            return @{
                ModuleBase = 'TestDrive:\'
                ModuleName = 'MyModule'
                Path       = 'TestDrive:\MyModule.psd1'
            }
        } -ParameterFilter {$Name -like '*.psd1'}

        It 'overrides properly the Script parameters for Invoke-Pester' {
            $result = Invoke-DscResourceTest -Script @{Path = '.'; Parameters = @{'ModuleName' = 'dummy'}} -Module 'Microsoft.PowerShell.Utility'
            $result.Script.Parameters.ModuleName  | Should -Not -BeExactly 'dummy'
            $result.script.Parameters.Keys | Should -HaveCount 10

        }
    }
}
