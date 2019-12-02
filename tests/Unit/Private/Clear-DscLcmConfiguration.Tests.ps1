$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Clear-DscLcmConfiguration' {

        Context 'When clearing the DSC LCM' {
            It 'Should reset the LCM without throwing' -Skip:($PSVersionTable.PSVersion.Major -gt 5 ) {
                Mock -CommandName 'Remove-DscConfigurationDocument'
                Mock -CommandName 'Stop-DscConfiguration'
                { Clear-DscLcmConfiguration } | Should -Not -Throw

                Assert-MockCalled -CommandName 'Stop-DscConfiguration' -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Current'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Pending'
                } -Exactly -Times 1 -Scope It

                Assert-MockCalled -CommandName 'Remove-DscConfigurationDocument' -ParameterFilter {
                    $Stage -eq 'Previous'
                } -Exactly -Times 1 -Scope It
            }
        }
    }

}
