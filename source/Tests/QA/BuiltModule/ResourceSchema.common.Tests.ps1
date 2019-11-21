[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourceManifest
)
Describe 'Common Tests - Script Resource Schema Validation' {
    Import-Module -Name xDscResourceDesigner -ErrorAction Stop
    $dscResourcesFolderFilePath = Join-Path -Path $ModuleBase -ChildPath 'DscResources'

    $scriptResourceNames = Get-ModuleScriptResourceName -ModulePath $ModuleBase
    foreach ($scriptResourceName in $scriptResourceNames)
    {
        Context $scriptResourceName {
            $scriptResourcePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $scriptResourceName

            It 'Should pass Test-xDscResource' {
                Test-xDscResource -Name $scriptResourcePath | Should -Be $true
            }

            It 'Should pass Test-xDscSchema' {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should -Be $true
            }
        }
    }
}
