[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param
(
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourceManifest
)

if ($isLinux -or $IsMacOS)
{
    $skipTests = $true

    Write-Warning "xDscResourceDesigner module only works on Windows at the moment."
    Write-Warning "Test-xDscResource & Test-xDscSchema will be skipped"
}
else
{
    $Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin)
    {
        $skipTests = $false
    }
    else
    {
        Write-Warning "xDscResourceDesigner needs your session to be running elevated."
        Write-Warning "Test-xDscResource & Test-xDscSchema will be skipped"

        $skipTests = $true
    }
}
Describe 'Common Tests - Script Resource Schema Validation' -Tag WindowsOnly {
    if ($isAdmin -and ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop'))
    {
        Import-Module -Name xDscResourceDesigner -ErrorAction 'Stop'
    }

    $dscResourcesFolderFilePath = Join-Path -Path $ModuleBase -ChildPath 'DscResources'
    $scriptResourceNames = Get-ModuleScriptResourceName -ModulePath $ModuleBase

    foreach ($scriptResourceName in $scriptResourceNames)
    {
        Context $scriptResourceName {
            $scriptResourcePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $scriptResourceName

            It 'Should pass Test-xDscResource' -Skip:$skipTests {
                Test-xDscResource -Name $scriptResourcePath | Should -Be $true
            }

            It 'Should pass Test-xDscSchema' -Skip:$skipTests {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should -Be $true
            }
        }
    }
}
