[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourceManifest
)


$Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Describe 'Common Tests - Script Resource Schema Validation' -Tag WindowsOnly {
    if ($isAdmin -and ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'))
    {
        Import-Module -Name xDscResourceDesigner -ErrorAction Stop
    }

    $dscResourcesFolderFilePath = Join-Path -Path $ModuleBase -ChildPath 'DscResources'
    $scriptResourceNames = Get-ModuleScriptResourceName -ModulePath $ModuleBase
    foreach ($scriptResourceName in $scriptResourceNames)
    {
        Context $scriptResourceName {
            $scriptResourcePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $scriptResourceName

            It 'Should pass Test-xDscResource' -Skip:(!$isAdmin -or !($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')) {
                Test-xDscResource -Name $scriptResourcePath | Should -Be $true
            }

            It 'Should pass Test-xDscSchema' -Skip:(!$isAdmin -or !($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')) {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should -Be $true
            }
        }
    }
}
