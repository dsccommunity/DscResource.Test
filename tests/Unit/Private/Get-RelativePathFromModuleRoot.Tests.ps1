$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-RelativePathFromModuleRoot' {
        Context 'When to get the relative path from module root' {
            BeforeAll {
                $relativePath = 'Modules'
                $filePath = Join-Path $TestDrive -ChildPath $relativePath
                $moduleRootPath = $TestDrive

                # Adds a backslash to make sure it gets trimmed.
                $filePath += [io.path]::DirectorySeparatorChar
            }

            It 'Should return the correct relative path' {
                $result = Get-RelativePathFromModuleRoot `
                    -FilePath $filePath `
                    -ModuleRootFilePath $moduleRootPath

                $result | Should -Be $relativePath
            }
        }
    }
}
