$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Test-FileHasByteOrderMark' {
        Context 'When a file has Byte Order Mark (BOM)' {
            BeforeAll {
                $fileName = 'TestByteOrderMark.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $Utf8withBomEncoding = [System.Text.UTF8Encoding]::new($true)
                [System.IO.File]::WriteAllLines($filePath, $fileName, $Utf8withBomEncoding)
            }

            It 'Should return $true' {
                $result = Test-FileHasByteOrderMark -FilePath $filePath
                $result | Should -Be $true
            }
        }

        Context 'When a file has no Byte Order Mark (BOM)' {
            BeforeAll {
                $fileName = 'TestNoByteOrderMark.ps1'
                $filePath = Join-Path $TestDrive -ChildPath $fileName

                $fileName | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $false' {
                $result = Test-FileHasByteOrderMark -FilePath $filePath
                $result | Should -Be $false
            }
        }
    }
}