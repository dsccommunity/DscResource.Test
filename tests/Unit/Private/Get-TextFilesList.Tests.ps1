$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {

    Describe 'Get-TextFilesList' {
        BeforeAll {
            $mofFileType = 'test.schema.mof'
            $psm1FileType = 'test.psm1'

            'resource_schema1' | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $mofFileType) -Encoding ascii
            'resource_schema2' | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $psm1FileType) -Encoding ascii
        }

        Context 'When a module contains text files' {
            It 'Should return all the file names of all the text files' {
                $result = Get-TextFilesList -Root $TestDrive
                $result.Count | Should -Be 2

                # Uncertain of returned order, so verify so each value is in the array.
                (Split-Path $result[0] -Leaf) | Should -BeIn @($mofFileType, $psm1FileType)
                (Split-Path $result[1] -Leaf) | Should -BeIn @($mofFileType, $psm1FileType)
            }
        }
    }
}