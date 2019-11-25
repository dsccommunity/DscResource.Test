$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-SuppressedPSSARuleNameList' {
        BeforeAll {
            $rule1 = "'PSAvoidUsingConvertToSecureStringWithPlainText'"
            $rule2 = "'PSAvoidGlobalVars'"

            $scriptPath = Join-Path -Path $TestDrive -ChildPath 'TestModule.psm1'
        }

        Context 'When a module files contains suppressed rules' {
            It 'Should return the all the suppressed rules' {
                "
            # Testing suppressing this rule
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($rule1, '')]
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute($rule2, '')]
            param()
            " | Out-File -FilePath $scriptPath -Encoding ascii -Force

                $result = Get-SuppressedPSSARuleNameList -FilePath $scriptPath
                $result.Count | Should -Be 4
                $result[0] | Should -Be $rule1
                $result[1] | Should -Be "''"
                $result[2] | Should -Be $rule2
                $result[3] | Should -Be "''"
            }
        }
    }
}
