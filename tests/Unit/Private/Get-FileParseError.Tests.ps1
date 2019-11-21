$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-FileParseErrors' {
        BeforeAll {
            $filePath = (Join-Path -Path $TestDrive -ChildPath 'test.psm1')
        }

        Context 'When a module does not contain parse errors' {
            BeforeEach {
                'function MockTestFunction {}' | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return $null' {
                Get-FileParseError -FilePath $filePath | Should -BeNullOrEmpty
            }
        }

        Context 'When a module do contain parse errors' {
            BeforeEach {
                # The param() is deliberately spelled wrong to get a parse error.
                'function MockTestFunction { parm() }' | Out-File -FilePath $filePath -Encoding ascii
            }

            It 'Should return the correct error string' {
                Get-FileParseError -FilePath $filePath | Should -Match 'An expression was expected after ''\('''
            }
        }
    }
}