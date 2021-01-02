[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param
(
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourcePath,
    $SourceManifest,
    $Tag,
    $ExcludeTag,
    $ExcludeModuleFile,
    $ExcludeSourceFile,
    $MainGitBranch
)

$isPester5 = (Get-Module -Name Pester).Version -lt '5.0.0'

# Only run if _not_ Pester 5.
if (-not $isPester5)
{
    return
}

Describe 'Common Tests - Script Resource Schema Validation' -Tag 'WindowsOnly' {
    if ($IsLinux -or $IsMacOS)
    {
        $skipTests = $true

        Write-Warning 'xDscResourceDesigner module only works on Windows at the moment.'
        Write-Warning 'Test-xDscResource & Test-xDscSchema will be skipped.'
    }
    else
    {
        $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin)
        {
            $skipTests = $false
        }
        else
        {
            Write-Warning 'xDscResourceDesigner needs your session to be running elevated.'
            Write-Warning 'Test-xDscResource & Test-xDscSchema will be skipped.'

            $skipTests = $true
        }
    }

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
                Test-xDscResource -Name $scriptResourcePath | Should -BeTrue
            }

            It 'Should pass Test-xDscSchema' -Skip:$skipTests {
                $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath "$scriptResourceName.schema.mof"
                Test-xDscSchema -Path $mofSchemaFilePath | Should -BeTrue
            }
        }
    }
}
