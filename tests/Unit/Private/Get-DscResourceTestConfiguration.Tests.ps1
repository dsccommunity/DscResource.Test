$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-DscResourceTestConfiguration' {

        Mock Get-StructuredObjectFromFile -MockWith { Param($Path) $Path }
        Mock ConvertTo-OrderedDictionary -MockWith { Param($Configuration) $Configuration }
        Mock Write-Debug

        It 'Should have correct code path when passing IDictionary' {
            $null = Get-DscResourceTestConfiguration -Configuration @{ }
            Assert-MockCalled -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a Dictionary' }
            Assert-MockCalled -CommandName ConvertTo-OrderedDictionary -Scope It
        }

        It 'Should have correct code path when passing PSCustomObject' {
            $null = Get-DscResourceTestConfiguration -Configuration ([PSCustomObject]@{ })
            Assert-MockCalled -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a PSCustomObject' }
            Assert-MockCalled -CommandName ConvertTo-OrderedDictionary -Scope It
        }

        It 'Should have correct code path when passing a path' {
            $null = Get-DscResourceTestConfiguration -Configuration 'TestDrive:\.MetaOptIn.json'
            Assert-MockCalled -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
            Assert-MockCalled -CommandName Get-StructuredObjectFromFile -Scope It
            Assert-MockCalled -CommandName ConvertTo-OrderedDictionary -Scope It
        }

        It 'Should use MetaOptIn file by default' {
            $null = Get-DscResourceTestConfiguration
            Assert-MockCalled -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
            Assert-MockCalled -CommandName Get-StructuredObjectFromFile -Scope It
            Assert-MockCalled -CommandName ConvertTo-OrderedDictionary -Scope It
        }

        It 'Should throw when called passing int' {
            {Get-DscResourceTestConfiguration -Configuration 2} | Should -Throw
        }
    }
}