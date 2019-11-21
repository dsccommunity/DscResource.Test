$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Test-FileInUnicode' {
        Context 'When a file is unicode' {
            BeforeAll {
                $fileName = 'TestUnicode.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding unicode
            }

            It 'Should return $true' {
                $result = Test-FileInUnicode -FileInfo $filePath
                $result | Should -Be $true
            }
        }

        Context 'When a file is not unicode' {
            BeforeAll {
                $fileName = 'TestNotUnicode.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $false' {
                $result = Test-FileInUnicode -FileInfo $filePath
                $result | Should -Be $false
            }
        }
    }
}