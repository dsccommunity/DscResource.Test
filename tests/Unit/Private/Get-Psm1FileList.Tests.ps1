$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-Psm1FileList' {
        BeforeAll {
            $psm1FileType = 'test.psm1'
            $filePath = Join-Path -Path $TestDrive -ChildPath $psm1FileType
            'testfile' | Out-File -FilePath $filePath -Encoding ascii
        }

        Context 'When a module contains module files' {
            It 'Should return all the file names of all the module files' {
                $result = Get-Psm1FileList -FilePath $TestDrive
                $result.Name | Should -Be $psm1FileType
            }
        }
    }
}