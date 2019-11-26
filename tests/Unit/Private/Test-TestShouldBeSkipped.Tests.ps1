$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Test-TestShouldBeSkipped' {
        #Skip if any TestNames is excluded or TAG is used and not in the TestNames
        $Cases = @(

            @{
                TestNames  = @('Test1', 'Test 1')
                Tag        = @('Test1')
                ExcludeTag = @()
                ShouldExclude = $false
                Description = 'Should Test1 be skipped when I only want Test1 = $false'
            },
            @{
                TestNames  = @('Test1', 'Test 1')
                Tag        = @()
                ExcludeTag = @('Test 1')
                ShouldExclude = $true
                Description = 'Should Test1 be skipped when I exclude Test 1 = $true'
            },
            @{
                TestNames  = @('Test1', 'Test 1')
                Tag        = @()
                ExcludeTag = @('Test 2')
                ShouldExclude = $false
                Description = 'Should Test1 be skipped when I exclude Test2 = $false'
            },
            @{
                TestNames  = @('Test1', 'Test 1')
                Tag        = @()
                ExcludeTag = @()
                ShouldExclude = $false
                Description = 'Should Test1 be skipped when I dont specify = $false'
            }
        )

        It 'Skip:<ShouldExclude> the specified test <testNames>' -TestCases $Cases {
            param
            (
                $TestNames,
                $Tag,
                $ExcludeTag,
                $ShouldExclude
            )

            Test-TestShouldBeSkipped -TestNames $TestNames -Tag $Tag -ExcludeTag $ExcludeTag | Should -be $ShouldExclude
        }
    }
}
