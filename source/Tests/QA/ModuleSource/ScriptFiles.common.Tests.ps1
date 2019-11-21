param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourcePath,
    $SourceManifest
)

Describe 'Common Tests - Validate Script Files' -Tag 'Script','Common Tests - Validate Script Files' {

    $scriptFiles = Get-ChildItem $SourcePath -Recurse -Include *.ps1
    Write-Debug -Message "Processing $($scriptFiles.Count) files..."

    foreach ($scriptFile in $scriptFiles)
    {
        Write-Debug -Message "... $scriptFile"
        $filePathOutputName = Get-RelativePathFromModuleRoot `
            -FilePath $scriptFile.FullName `
            -ModuleRootFilePath $SourcePath

        Context $filePathOutputName {
            It ('Script file ''{0}'' should not have Byte Order Mark (BOM)' -f $filePathOutputName) {
                $scriptFileHasBom = Test-FileHasByteOrderMark -FilePath $scriptFile.FullName

                if ($scriptFileHasBom)
                {
                    Write-Warning -Message "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
                }

                $scriptFileHasBom | Should -Be $false -Because "$filePathOutputName contain Byte Order Mark (BOM). Use fixer function 'ConvertTo-ASCII'."
            }
        }
    }
}
